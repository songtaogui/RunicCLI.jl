function _compile_cmd_block(block::Expr)
    fields = Expr[]
    option_parse_stmts = Expr[]
    positional_parse_stmts = Expr[]
    post_stmts = Expr[]
    group_defs = Vector{Vector{Symbol}}()
    argdefs_expr = Expr[]

    declared_names = Set{Symbol}()
    name_kind = Dict{Symbol,ArgKind}()
    seen_pos_rest = false

    flag_owner = Dict{String,Symbol}()

    local function _expect_name_symbol(x, macro_name::String, role::String)::Symbol
        if x isa Symbol
            return x
        elseif x isa QuoteNode && x.value isa Symbol
            return x.value
        elseif x isa Expr
            if x.head == :quote && length(x.args) == 1
                q = x.args[1]
                if q isa Symbol
                    return q
                end
            elseif x.head == :global && length(x.args) == 1 && x.args[1] isa Symbol
                return x.args[1]
            elseif x.head == :local && length(x.args) == 1 && x.args[1] isa Symbol
                return x.args[1]
            elseif x.head == :const && length(x.args) == 1 && x.args[1] isa Symbol
                return x.args[1]
            end
        end
        throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
    end

    # 解析“参数名 + 后续参数”。
    # 兼容关键字名写法导致的 AST 形态：
    #   @ARG_FLAG global "-g"
    # 其中 name 位会变成 Expr(:global, "-g")，这里修正为：
    #   name = :global, rest 追加 "-g"
    local function _extract_name_and_rest(node::Expr, name_idx::Int, macro_name::String, role::String)
        x = node.args[name_idx]
        tail = Any[node.args[i] for i in (name_idx + 1):length(node.args)]

        if x isa Symbol
            return x, tail
        elseif x isa QuoteNode && x.value isa Symbol
            return x.value, tail
        elseif x isa Expr
            if x.head == :quote && length(x.args) == 1 && x.args[1] isa Symbol
                return x.args[1], tail
            elseif x.head in (:global, :local, :const) && length(x.args) == 1
                a = x.args[1]
                if a isa Symbol
                    return a, tail
                elseif a isa String || (a isa QuoteNode && a.value isa String)
                    # 关键字名 + 第一个后续参数被 parser 吃进 Expr
                    return Symbol(String(x.head)), Any[a, tail...]
                end
            end
        end

        throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
    end

    local function _validate_flag!(f::String, macro_name::String)
        isempty(strip(f)) && throw(ArgumentError("$(macro_name) flag must not be empty"))
        occursin(r"\s", f) && throw(ArgumentError("$(macro_name) flag must not contain whitespace: $(repr(f))"))
        (startswith(f, "-") && f != "-" && f != "--") || throw(ArgumentError("$(macro_name) invalid flag: $(f)"))
        if startswith(f, "-") && !startswith(f, "--") && length(f) != 2
            throw(ArgumentError("$(macro_name) short flag must be exactly one character: $(f)"))
        end
    end

    local function _register_flags!(flags::Vector{String}, owner::Symbol, macro_name::String)
        for f in flags
            _validate_flag!(f, macro_name)
            if haskey(flag_owner, f)
                throw(ArgumentError("duplicate flag detected: $(f) used by $(flag_owner[f]) and $(owner)"))
            end
            flag_owner[f] = owner
        end
    end

    local function _extract_flags!(rest::Vector{Any}, macro_name::String)
        flags = String[]
        for x in rest
            if x isa String
                push!(flags, x)
            elseif x isa QuoteNode && x.value isa String
                push!(flags, x.value)
            else
                throw(ArgumentError("$(macro_name) flags must be String literals; got $(repr(x))"))
            end
        end
        return flags
    end

    for node in _getmacrocalls(block)
        m = _getmacroname(node)
        m === nothing && throw(ArgumentError("unsupported DSL macro expression"))

        if m == SYM_GROUP
            syms = Symbol[]
            for i in 3:length(node.args)
                push!(syms, _expect_name_symbol(node.args[i], "@GROUP_EXCL", "argument name"))
            end
            length(syms) < 2 && throw(ArgumentError("@GROUP_EXCL requires at least two argument names"))
            length(unique(syms)) != length(syms) && throw(ArgumentError("@GROUP_EXCL contains duplicate argument names"))
            push!(group_defs, syms)

        elseif m == SYM_REQ
            T = node.args[3]
            nm, rest = _extract_name_and_rest(node, 4, "@ARG_REQ", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@ARG_REQ")
            flags = _extract_flags!(rest, "@ARG_REQ")
            isempty(flags) && throw(ArgumentError("@ARG_REQ requires at least one flag"))
            _register_flags!(flags, nm, "@ARG_REQ")

            provided_sym = Symbol("_provided_", nm)
            tmp_sym = Symbol("_tmp_", nm)

            push!(declared_names, nm)
            name_kind[nm] = AK_OPTION
            push!(fields, :($(nm)::$(T)))
            push!(option_parse_stmts, quote
                local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
                local _raw = $(tmp_sym)[1]
                local $(provided_sym) = $(tmp_sym)[2]
                isnothing(_raw) && $(_gr(:_throw_arg_error))("Missing required option $( $(flags[end]) )")
                local $(nm)::$(T) = $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), required=true, help=$(help), help_name=$(help_name))))

        elseif m == SYM_DEF
            T = node.args[3]
            dv = node.args[4]
            nm, rest = _extract_name_and_rest(node, 5, "@ARG_DEF", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@ARG_DEF")
            flags = _extract_flags!(rest, "@ARG_DEF")
            isempty(flags) && throw(ArgumentError("@ARG_DEF requires at least one flag"))
            _register_flags!(flags, nm, "@ARG_DEF")

            provided_sym = Symbol("_provided_", nm)
            tmp_sym = Symbol("_tmp_", nm)

            push!(declared_names, nm)
            name_kind[nm] = AK_OPTION
            push!(fields, :($(nm)::$(T)))
            push!(option_parse_stmts, quote
                local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
                local _raw = $(tmp_sym)[1]
                local $(provided_sym) = $(tmp_sym)[2]
                local $(nm)::$(T) = isnothing(_raw) ? $(_gr(:_convert_default))($(T), $(dv), $(string(nm))) : $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), default=$(dv), required=false, help=$(help), help_name=$(help_name))))

        elseif m == SYM_OPT
            T = node.args[3]
            nm, rest = _extract_name_and_rest(node, 4, "@ARG_OPT", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@ARG_OPT")
            flags = _extract_flags!(rest, "@ARG_OPT")
            isempty(flags) && throw(ArgumentError("@ARG_OPT requires at least one flag"))
            _register_flags!(flags, nm, "@ARG_OPT")

            provided_sym = Symbol("_provided_", nm)
            tmp_sym = Symbol("_tmp_", nm)

            push!(declared_names, nm)
            name_kind[nm] = AK_OPTION
            push!(fields, :($(nm)::Union{$(T),Nothing}))
            push!(option_parse_stmts, quote
                local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
                local _raw = $(tmp_sym)[1]
                local $(provided_sym) = $(tmp_sym)[2]
                local $(nm)::Union{$(T),Nothing} = isnothing(_raw) ? nothing : $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), required=false, help=$(help), help_name=$(help_name))))

        elseif m == SYM_FLAG
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_FLAG", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@ARG_FLAG")
            flags = _extract_flags!(rest, "@ARG_FLAG")
            isempty(flags) && throw(ArgumentError("@ARG_FLAG requires at least one flag"))
            _register_flags!(flags, nm, "@ARG_FLAG")

            flag_before_sym = Symbol("_flag_before_", nm)
            provided_sym = Symbol("_provided_", nm)

            push!(declared_names, nm)
            name_kind[nm] = AK_FLAG
            push!(fields, :($(nm)::Bool))
            push!(option_parse_stmts, quote
                local $(flag_before_sym) = length(_opt_args)
                local $(nm)::Bool = $(_gr(:_pop_flag!))(_opt_args, $(flags))
                local $(provided_sym) = ($(flag_before_sym) != length(_opt_args))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_FLAG)), name=$(QuoteNode(nm)), T=Bool, flags=$(flags), help=$(help), help_name=$(help_name))))

        elseif m == SYM_COUNT
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_COUNT", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@ARG_COUNT")
            flags = _extract_flags!(rest, "@ARG_COUNT")
            isempty(flags) && throw(ArgumentError("@ARG_COUNT requires at least one flag"))
            _register_flags!(flags, nm, "@ARG_COUNT")

            push!(declared_names, nm)
            name_kind[nm] = AK_COUNT
            push!(fields, :($(nm)::Int))

            cnt_sym = Symbol("_cnt_", nm)
            provided_sym = Symbol("_provided_", nm)
            count_stmts = [:( $cnt_sym += $(_gr(:_pop_count!))(_opt_args, $(f)) ) for f in flags]

            push!(option_parse_stmts, quote
                local $cnt_sym = 0
                $(count_stmts...)
                local $(nm)::Int = $cnt_sym
                local $provided_sym = ($(nm) > 0)
            end)

            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_COUNT)), name=$(QuoteNode(nm)), T=Int, flags=$(flags), help=$(help), help_name=$(help_name))))

        elseif m == SYM_MULTI
            T = node.args[3]
            nm, rest = _extract_name_and_rest(node, 4, "@ARG_MULTI", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@ARG_MULTI")
            flags = _extract_flags!(rest, "@ARG_MULTI")
            isempty(flags) && throw(ArgumentError("@ARG_MULTI requires at least one flag"))
            _register_flags!(flags, nm, "@ARG_MULTI")

            provided_sym = Symbol("_provided_", nm)

            push!(declared_names, nm)
            name_kind[nm] = AK_OPTION_MULTI
            push!(fields, :($(nm)::Vector{$(T)}))
            push!(option_parse_stmts, quote
                local _vals = $(_gr(:_pop_multi_values!))(_opt_args, $(flags), allow_empty_option_value)
                local $(provided_sym) = !isempty(_vals)
                local $(nm)::Vector{$(T)} = [ $(_gr(:_parse_value))($(T), v, $(string(nm))) for v in _vals ]
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION_MULTI)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), help=$(help), help_name=$(help_name))))

        elseif m == SYM_POS_REQ
            T = node.args[3]
            nm, rest = _extract_name_and_rest(node, 4, "@POS_REQ", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@POS_REQ")
            isempty(rest) || throw(ArgumentError("@POS_REQ supports only keyword metadata: help=\"...\", help_name=\"...\""))

            provided_sym = Symbol("_provided_", nm)

            seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))
            push!(declared_names, nm)
            name_kind[nm] = AK_POS_REQUIRED
            push!(fields, :($(nm)::$(T)))
            push!(positional_parse_stmts, quote
                isempty(_args) && $(_gr(:_throw_arg_error))("Missing required positional $( $(string(nm)) )")
                local $(provided_sym) = true
                local $(nm)::$(T) = $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_REQUIRED)), name=$(QuoteNode(nm)), T=$(T), required=true, help=$(help), help_name=$(help_name))))

        elseif m == SYM_POS_DEF
            T = node.args[3]
            dv = node.args[4]
            nm, rest = _extract_name_and_rest(node, 5, "@POS_DEF", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@POS_DEF")
            isempty(rest) || throw(ArgumentError("@POS_DEF supports only keyword metadata: help=\"...\", help_name=\"...\""))

            provided_sym = Symbol("_provided_", nm)

            seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))
            push!(declared_names, nm)
            name_kind[nm] = AK_POS_DEFAULT
            push!(fields, :($(nm)::$(T)))
            push!(positional_parse_stmts, quote
                local $(provided_sym) = !isempty(_args)
                local $(nm)::$(T) = isempty(_args) ? $(_gr(:_convert_default))($(T), $(dv), $(string(nm))) : $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_DEFAULT)), name=$(QuoteNode(nm)), T=$(T), default=$(dv), help=$(help), help_name=$(help_name))))

        elseif m == SYM_POS_OPT
            T = node.args[3]
            nm, rest = _extract_name_and_rest(node, 4, "@POS_OPT", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@POS_OPT")
            isempty(rest) || throw(ArgumentError("@POS_OPT supports only keyword metadata: help=\"...\", help_name=\"...\""))

            provided_sym = Symbol("_provided_", nm)

            seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))
            push!(declared_names, nm)
            name_kind[nm] = AK_POS_OPTIONAL
            push!(fields, :($(nm)::Union{$(T),Nothing}))
            push!(positional_parse_stmts, quote
                local $(provided_sym) = !isempty(_args)
                local $(nm)::Union{$(T),Nothing} = isempty(_args) ? nothing : $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_OPTIONAL)), name=$(QuoteNode(nm)), T=$(T), help=$(help), help_name=$(help_name))))

        elseif m == SYM_POS_RST
            T = node.args[3]
            nm, rest = _extract_name_and_rest(node, 4, "@POS_REST", "argument name")
            nm in declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))
            help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name="@POS_REST")
            isempty(rest) || throw(ArgumentError("@POS_REST supports only keyword metadata: help=\"...\", help_name=\"...\""))

            provided_sym = Symbol("_provided_", nm)

            seen_pos_rest && throw(ArgumentError("only one @POS_REST is allowed and it must be last"))
            seen_pos_rest = true
            push!(declared_names, nm)
            name_kind[nm] = AK_POS_REST
            push!(fields, :($(nm)::Vector{$(T)}))
            push!(positional_parse_stmts, quote
                local $(provided_sym) = !isempty(_args)
                local $(nm)::Vector{$(T)} = [ $(_gr(:_parse_value))($(T), x, $(string(nm))) for x in _args ]
                empty!(_args)
            end)
            push!(argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_REST)), name=$(QuoteNode(nm)), T=$(T), help=$(help), help_name=$(help_name))))

        elseif m == SYM_TEST
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_TEST", "argument name")
            nm in declared_names || throw(ArgumentError("@ARG_TEST references unknown argument: $(nm)"))
            isempty(rest) && throw(ArgumentError("@ARG_TEST requires a validator function"))
            fn = rest[1]
            msg = if length(rest) >= 2
                rest[2] isa String || throw(ArgumentError("@ARG_TEST message must be a String literal"))
                rest[2]
            else
                "Argument test failed: $(nm)"
            end
            length(rest) <= 2 || throw(ArgumentError("@ARG_TEST accepts at most one message String"))

            push!(post_stmts, quote
                if !(isnothing($(nm)) || $(fn)($(nm)))
                    local _vname = try String(nameof($(fn))) catch; "validator" end
                    $(_gr(:_throw_arg_error))($(msg) * " (arg=$(string($(QuoteNode(nm)))), validator=" * _vname * ", value=" * repr($(nm)) * ")")
                end
            end)

        elseif m == SYM_STREAM
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_STREAM", "argument name")
            nm in declared_names || throw(ArgumentError("@ARG_STREAM references unknown argument: $(nm)"))
            isempty(rest) && throw(ArgumentError("@ARG_STREAM requires a validator function"))
            fn = rest[1]
            msg = if length(rest) >= 2
                rest[2] isa String || throw(ArgumentError("@ARG_STREAM message must be a String literal"))
                rest[2]
            else
                "Streaming validation failed: $(nm)"
            end
            length(rest) <= 2 || throw(ArgumentError("@ARG_STREAM accepts at most one message String"))

            push!(post_stmts, quote
                local _vname = try String(nameof($(fn))) catch; "validator" end
                local _fails = String[]
                if $(nm) isa AbstractVector
                    for _v in $(nm)
                        if !$(fn)(_v)
                            push!(_fails, repr(_v))
                        end
                    end
                elseif !(isnothing($(nm)) || $(fn)($(nm)))
                    push!(_fails, repr($(nm)))
                end
                if !isempty(_fails)
                    $(_gr(:_throw_arg_error))($(msg) * " (arg=$(string($(QuoteNode(nm)))), validator=" * _vname * ", failed_values=[" * join(_fails, ", ") * "])")
                end
            end)
        else
            throw(ArgumentError("unsupported DSL macro: $(m)"))
        end
    end

    for grp in group_defs, s in grp
        if !(s in declared_names)
            throw(ArgumentError("@GROUP_EXCL references unknown argument: $(s)"))
        end
    end

    for grp in group_defs
        for s in grp
            if haskey(name_kind, s)
                k = name_kind[s]
                if k in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
                    throw(ArgumentError("@GROUP_EXCL supports only option-style arguments, got positional: $(s)"))
                end
            end
        end
    end

    return fields, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr, group_defs
end
