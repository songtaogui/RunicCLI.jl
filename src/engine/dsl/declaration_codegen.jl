function _validator_default_message(style::Symbol)
    style in (:multi, :pos_rest) ? "Streaming validation failed" : "Argument test failed"
end

function _emit_scalar_validator_stmt(
    nm::Symbol,
    vfun_expr,
    vmsg_text::String,
    default_msg::String;
    skip_nothing::Bool=false
)
    vmsg_expr = isempty(vmsg_text) ? :(nothing) : vmsg_text

    cond = skip_nothing ? :(!(isnothing($(nm)) || _vfn($(nm)))) : :(!_vfn($(nm)))

    return quote
        local _vs = $(_gr(:validator))($(vfun_expr))
        local _vfn = $(_gr(:validator_fn))(_vs)
        local _final_msg = $(_gr(:validator_resolve_message))(_vs, $(vmsg_expr), $(default_msg))
        if $(cond)
            local _vname = $(_gr(:validator_name))(_vs)
            $(_gr(:_throw_arg_error))(
                "Invalid arg: " * $(string(nm)) * " => " * _final_msg *
                "\n (validator=" * _vname * ", value=" * repr($(nm)) * ")"
            )
        end
    end
end

function _emit_stream_validator_stmt(
    nm::Symbol,
    vfun_expr,
    vmsg_text::String,
    default_msg::String
)
    vmsg_expr = isempty(vmsg_text) ? :(nothing) : vmsg_text

    return quote
        local _vs = $(_gr(:validator))($(vfun_expr))
        local _vfn = $(_gr(:validator_fn))(_vs)
        local _vname = $(_gr(:validator_name))(_vs)
        local _final_msg = $(_gr(:validator_resolve_message))(_vs, $(vmsg_expr), $(default_msg))
        local _fails = String[]
        for _v in $(nm)
            if !_vfn(_v)
                push!(_fails, repr(_v))
            end
        end
        if !isempty(_fails)
            $(_gr(:_throw_arg_error))(
                "Invalid arg: " * $(string(nm)) * " => " * _final_msg *
                "\n (validator=" * _vname * ", failed_values=[" * join(_fails, ", ") * "])"
            )
        end
    end
end

function _parse_decl_pipeline!(ctx::_CompileCtx, spec::ArgDeclSpec, node::Expr)
    idx = 3

    T = nothing
    if spec.has_type
        idx > length(node.args) && throw(ArgumentError("$(spec.macro_name) expects a type parameter"))
        T = node.args[idx]
        idx += 1
    end

    idx > length(node.args) && throw(ArgumentError("$(spec.macro_name) expects an argument name"))
    nm, rest = _extract_name_and_rest(node, idx, spec.macro_name, "argument name")

    nm in ctx.declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))

    meta = _extract_decl_meta!(
        rest;
        allow_help_name=true,
        allow_env=spec.allow_env,
        allow_default=spec.allow_default,
        allow_fallback=spec.allow_fallback,
        macro_name=spec.macro_name
    )

    flags = String[]
    if spec.require_flags
        flags = _extract_flags!(meta.remain, spec.macro_name)
        isempty(flags) && throw(ArgumentError("$(spec.macro_name) requires at least one flag"))
        _register_flags!(ctx, flags, nm, spec.macro_name)
    else
        isempty(meta.remain) || throw(ArgumentError(
            "$(spec.macro_name) supports only keyword metadata: " *
            "help=\"...\", help_name=\"...\"" *
            "$(spec.allow_env ? ", env=\"...\"" : "")" *
            "$(spec.allow_default ? ", default=..." : "")" *
            "$(spec.allow_fallback ? ", fallback=other_arg" : "")" *
            ", vfun=..., vmsg=\"...\""
        ))
    end

    push!(ctx.declared_names, nm)
    ctx.name_kind[nm] = spec.kind

    return (
        nm=nm,
        T=T,
        flags=flags,
        help=meta.help,
        help_name=meta.help_name,
        env=meta.env,
        has_default=meta.has_default,
        default=meta.default,
        fallback=meta.fallback,
        vfun=meta.vfun,
        vmsg=meta.vmsg,
        style=spec.style,
        kind=spec.kind
    )
end

function _emit_decl_opt_required!(ctx::_CompileCtx, d)
    nm, T, flags, help, help_name = d.nm, d.T, d.flags, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    tmp_sym = Symbol("_tmp_", nm)

    push!(ctx.fields, :($(nm)::$(T)))
    push!(ctx.option_parse_stmts, quote
        local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
        local _raw = $(tmp_sym)[1]
        local $(provided_sym) = $(tmp_sym)[2]
        isnothing(_raw) && $(_gr(:_throw_arg_error))($(_gr(:_msg_missing_required_option))($(flags[end])))
        local $(nm)::$(T) = $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), required=true, help=$(help), help_name=$(help_name))))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_scalar_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style); skip_nothing=false
        ))
    end
end

function _emit_decl_opt_optional!(ctx::_CompileCtx, d)
    nm, T, flags, help, help_name, env, fallback = d.nm, d.T, d.flags, d.help, d.help_name, d.env, d.fallback
    has_default, default_expr = d.has_default, d.default
    provided_sym = Symbol("_provided_", nm)
    tmp_sym = Symbol("_tmp_", nm)
    fallback_applied_sym = Symbol("_fallback_applied_", nm)

    fieldT = :(Union{$(T),Nothing})

    push!(ctx.fields, :($(nm)::$(fieldT)))
    push!(ctx.option_parse_stmts, quote
        local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
        local _cli_raw = $(tmp_sym)[1]
        local $(provided_sym) = $(tmp_sym)[2]

        local _env_raw = nothing
        if isnothing(_cli_raw) && $(env !== nothing)
            _env_raw = get(ENV, $(env), nothing)
        end

        local $(nm)::$(fieldT) =
            if !isnothing(_cli_raw)
                $(_gr(:_parse_value))($(T), _cli_raw, $(string(nm)))
            elseif !isnothing(_env_raw)
                $(_gr(:_parse_value))($(T), _env_raw, $(string(nm)))
            elseif $(has_default)
                $(_gr(:_convert_default))($(T), $(default_expr), $(string(nm)))
            else
                nothing
            end

        local $(fallback_applied_sym) = false
    end)

    if fallback !== nothing
        ctx.fallback_map[nm] = fallback
        push!(ctx.post_stmts, quote
            if isnothing($(nm)) && !isnothing($(fallback))
                $(nm) = $(fallback)
                $(fallback_applied_sym) = true
            end
        end)
    end

    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(
        kind=$(_gr(:AK_OPTION)),
        name=$(QuoteNode(nm)),
        T=$(T),
        flags=$(flags),
        required=false,
        default=$(has_default ? default_expr : nothing),
        help=$(help),
        help_name=$(help_name),
        env=$(env),
        fallback=$(fallback === nothing ? nothing : QuoteNode(fallback))
    )))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_scalar_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style); skip_nothing=true
        ))
    end
end

function _emit_decl_flag!(ctx::_CompileCtx, d)
    nm, flags, help, help_name = d.nm, d.flags, d.help, d.help_name
    flag_before_sym = Symbol("_flag_before_", nm)
    provided_sym = Symbol("_provided_", nm)

    push!(ctx.fields, :($(nm)::Bool))
    push!(ctx.option_parse_stmts, quote
        local $(flag_before_sym) = length(_opt_args)
        local $(nm)::Bool = $(_gr(:_pop_flag!))(_opt_args, $(flags))
        local $(provided_sym) = ($(flag_before_sym) != length(_opt_args))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_FLAG)), name=$(QuoteNode(nm)), T=Bool, flags=$(flags), help=$(help), help_name=$(help_name))))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_scalar_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style); skip_nothing=false
        ))
    end
end

function _emit_decl_count!(ctx::_CompileCtx, d)
    nm, flags, help, help_name = d.nm, d.flags, d.help, d.help_name
    cnt_sym = Symbol("_cnt_", nm)
    provided_sym = Symbol("_provided_", nm)
    count_stmts = [:( $cnt_sym += $(_gr(:_pop_count!))(_opt_args, $(f)) ) for f in flags]

    push!(ctx.fields, :($(nm)::Int))
    push!(ctx.option_parse_stmts, quote
        local $cnt_sym = 0
        $(count_stmts...)
        local $(nm)::Int = $cnt_sym
        local $provided_sym = ($(nm) > 0)
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_COUNT)), name=$(QuoteNode(nm)), T=Int, flags=$(flags), help=$(help), help_name=$(help_name))))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_scalar_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style); skip_nothing=false
        ))
    end
end

function _emit_decl_multi!(ctx::_CompileCtx, d)
    nm, T, flags, help, help_name = d.nm, d.T, d.flags, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)

    push!(ctx.fields, :($(nm)::Vector{$(T)}))
    push!(ctx.option_parse_stmts, quote
        local _vals = $(_gr(:_pop_multi_values!))(_opt_args, $(flags), allow_empty_option_value)
        local $(provided_sym) = !isempty(_vals)
        local $(nm)::Vector{$(T)} = [ $(_gr(:_parse_value))($(T), v, $(string(nm))) for v in _vals ]
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION_MULTI)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), help=$(help), help_name=$(help_name))))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_stream_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style)
        ))
    end
end

function _emit_decl_pos_required!(ctx::_CompileCtx, d)
    nm, T, help, help_name = d.nm, d.T, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))

    push!(ctx.fields, :($(nm)::$(T)))
    push!(ctx.positional_parse_stmts, quote
        isempty(_args) && $(_gr(:_throw_arg_error))($(_gr(:_msg_missing_required_positional))($(string(nm))))
        local $(provided_sym) = true
        local $(nm)::$(T) = $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_REQUIRED)), name=$(QuoteNode(nm)), T=$(T), required=true, help=$(help), help_name=$(help_name))))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_scalar_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style); skip_nothing=false
        ))
    end
end

function _emit_decl_pos_optional!(ctx::_CompileCtx, d)
    nm, T, help, help_name, env, fallback = d.nm, d.T, d.help, d.help_name, d.env, d.fallback
    has_default, default_expr = d.has_default, d.default
    provided_sym = Symbol("_provided_", nm)
    fallback_applied_sym = Symbol("_fallback_applied_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))

    fieldT = :(Union{$(T),Nothing})

    push!(ctx.fields, :($(nm)::$(fieldT)))
    push!(ctx.positional_parse_stmts, quote
        local $(provided_sym) = !isempty(_args)

        local _cli_raw = isempty(_args) ? nothing : popfirst!(_args)
        local _env_raw = nothing
        if isnothing(_cli_raw) && $(env !== nothing)
            _env_raw = get(ENV, $(env), nothing)
        end

        local $(nm)::$(fieldT) =
            if !isnothing(_cli_raw)
                $(_gr(:_parse_value))($(T), _cli_raw, $(string(nm)))
            elseif !isnothing(_env_raw)
                $(_gr(:_parse_value))($(T), _env_raw, $(string(nm)))
            elseif $(has_default)
                $(_gr(:_convert_default))($(T), $(default_expr), $(string(nm)))
            else
                nothing
            end

        local $(fallback_applied_sym) = false
    end)

    if fallback !== nothing
        ctx.fallback_map[nm] = fallback
        push!(ctx.post_stmts, quote
            if isnothing($(nm)) && !isnothing($(fallback))
                $(nm) = $(fallback)
                $(fallback_applied_sym) = true
            end
        end)
    end

    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(
        kind=$(_gr(:AK_POS_OPTIONAL)),
        name=$(QuoteNode(nm)),
        T=$(T),
        default=$(has_default ? default_expr : nothing),
        help=$(help),
        help_name=$(help_name),
        env=$(env),
        fallback=$(fallback === nothing ? nothing : QuoteNode(fallback))
    )))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_scalar_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style); skip_nothing=true
        ))
    end
end

function _emit_decl_pos_rest!(ctx::_CompileCtx, d)
    nm, T, help, help_name = d.nm, d.T, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("only one @POS_REST is allowed and it must be last"))
    ctx.seen_pos_rest = true

    push!(ctx.fields, :($(nm)::Vector{$(T)}))
    push!(ctx.positional_parse_stmts, quote
        local $(provided_sym) = !isempty(_args)
        local $(nm)::Vector{$(T)} = [ $(_gr(:_parse_value))($(T), x, $(string(nm))) for x in _args ]
        empty!(_args)
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_REST)), name=$(QuoteNode(nm)), T=$(T), help=$(help), help_name=$(help_name))))

    if d.vfun !== nothing
        push!(ctx.post_stmts, _emit_stream_validator_stmt(
            nm, d.vfun, d.vmsg, _validator_default_message(d.style)
        ))
    end
end

const _DECL_EMITTERS = Dict{Symbol,Function}(
    :opt_required => _emit_decl_opt_required!,
    :opt_optional => _emit_decl_opt_optional!,
    :flag         => _emit_decl_flag!,
    :count        => _emit_decl_count!,
    :multi        => _emit_decl_multi!,
    :pos_required => _emit_decl_pos_required!,
    :pos_optional => _emit_decl_pos_optional!,
    :pos_rest     => _emit_decl_pos_rest!,
)

function _emit_decl_codegen!(ctx::_CompileCtx, d)
    em = get(_DECL_EMITTERS, d.style, nothing)
    em === nothing && throw(ArgumentError("internal error: unsupported declaration style $(d.style)"))
    em(ctx, d)
end
