#FILEPATH: ./engine/dsl/compile_block.jl

function extract_rel_help!(args::Vector{Any}, macro_name::String)
    help = ""
    kept = Any[]
    for x in args
        if x isa Expr && x.head == :(=) && length(x.args) == 2 && x.args[1] == :help
            isempty(help) || argerr("$(macro_name) accepts at most one help=... keyword")
            x.args[2] isa String || argerr("$(macro_name) help must be a String literal")
            help = x.args[2]
        else
            push!(kept, x)
        end
    end
    return kept, help
end

expect_rel_member_symbol(x, macro_name::String) =
    x isa Symbol ? x :
    (x isa QuoteNode && x.value isa Symbol ? x.value :
     argerr("$(macro_name) expects argument names as Symbols"))

function parse_relation_expr(x, macro_name::String)::RelationExpr
    if x isa Symbol
        return RelAll(members=[x])
    elseif x isa QuoteNode && x.value isa Symbol
        return RelAll(members=[x.value])
    elseif x isa Expr && x.head == :call && !isempty(x.args)
        fn = x.args[1]
        if fn == :all
            length(x.args) >= 2 || argerr("$(macro_name) all(...) requires at least one argument name")
            members = [expect_rel_member_symbol(a, macro_name) for a in x.args[2:end]]
            ensure_no_duplicates!(members, macro_name, "all(...) members")
            return RelAll(members=members)
        elseif fn == :any
            length(x.args) >= 2 || argerr("$(macro_name) any(...) requires at least one argument name")
            members = [expect_rel_member_symbol(a, macro_name) for a in x.args[2:end]]
            ensure_no_duplicates!(members, macro_name, "any(...) members")
            return RelAny(members=members)
        elseif fn == :not
            length(x.args) == 2 || argerr("$(macro_name) not(...) requires exactly one inner expression")
            return RelNot(inner=parse_relation_expr(x.args[2], macro_name))
        end
    end
    argerr("$(macro_name) expects relation expression: a | all(a,b) | any(a,b) | not(...)")
end

# ---- handlers ----
function handle_argrel_depends!(ctx::CompileCtx, node::Expr)
    raw = Any[node.args[i] for i in 3:length(node.args)]
    raw, help = extract_rel_help!(raw, "@ARGREL_DEPENDS")
    length(raw) == 2 || argerr("@ARGREL_DEPENDS expects exactly two relation expressions")
    push!(ctx.relation_defs, ArgRelationDef(
        kind=:depends,
        lhs=parse_relation_expr(raw[1], "@ARGREL_DEPENDS"),
        rhs=parse_relation_expr(raw[2], "@ARGREL_DEPENDS"),
        help=help
    ))
end

function handle_argrel_conflicts!(ctx::CompileCtx, node::Expr)
    raw = Any[node.args[i] for i in 3:length(node.args)]
    raw, help = extract_rel_help!(raw, "@ARGREL_CONFLICTS")
    length(raw) == 2 || argerr("@ARGREL_CONFLICTS expects exactly two relation expressions")
    push!(ctx.relation_defs, ArgRelationDef(
        kind=:conflicts,
        lhs=parse_relation_expr(raw[1], "@ARGREL_CONFLICTS"),
        rhs=parse_relation_expr(raw[2], "@ARGREL_CONFLICTS"),
        help=help
    ))
end

function handle_argrel_group_kind!(ctx::CompileCtx, node::Expr, macro_name::String, kind::Symbol)
    raw = Any[node.args[i] for i in 3:length(node.args)]
    raw, help = extract_rel_help!(raw, macro_name)
    !isempty(raw) || argerr("$(macro_name) requires at least one argument name")
    members = [expect_rel_member_symbol(x, macro_name) for x in raw]
    ensure_no_duplicates!(members, macro_name, "argument names")
    push!(ctx.relation_defs, ArgRelationDef(kind=kind, members=members, help=help))
end

handle_argrel_atmostone!(ctx::CompileCtx, node::Expr) = handle_argrel_group_kind!(ctx, node, "@ARGREL_ATMOSTONE", :atmostone)
handle_argrel_atleastone!(ctx::CompileCtx, node::Expr) = handle_argrel_group_kind!(ctx, node, "@ARGREL_ATLEASTONE", :atleastone)
handle_argrel_onlyone!(ctx::CompileCtx, node::Expr) = handle_argrel_group_kind!(ctx, node, "@ARGREL_ONLYONE", :onlyone)
handle_argrel_allornone!(ctx::CompileCtx, node::Expr) = handle_argrel_group_kind!(ctx, node, "@ARGREL_ALLORNONE", :allornone)

function handle_arg_group!(ctx::CompileCtx, node::Expr)
    length(node.args) >= 4 || argerr("@ARG_GROUP requires title String and at least one argument name")
    title = node.args[3]
    title isa String || argerr("@ARG_GROUP title must be a String literal")
    isempty(strip(title)) && argerr("@ARG_GROUP title must not be empty")
    members = collect_symbol_args(node, 4, "@ARG_GROUP", "argument name")
    ensure_min_count!(members, 1, "@ARG_GROUP", "argument names")
    ensure_no_duplicates!(members, "@ARG_GROUP", "argument names")
    push!(ctx.arg_group_defs, ArgGroupDef(title=title, members=members))
end

function handle_arg_test!(ctx::CompileCtx, node::Expr)
    length(node.args) >= 4 || argerr("@ARG_TEST expects at least: @ARG_TEST arg_name... vfun=... [vmsg=\"...\"]")

    names = Symbol[]
    vfun_expr = nothing
    vmsg_text = ""
    seen_vfun = false
    seen_vmsg = false

    for i in 3:length(node.args)
        a = node.args[i]
        p = kw_pair(a)

        if p === nothing
            nm = expect_name_symbol(a, "@ARG_TEST", "argument name")
            push!(names, nm)
            continue
        end

        kraw, v = p
        k = kw_key_symbol(kraw)
        k === nothing && argerr("@ARG_TEST invalid keyword name: $(repr(kraw))")

        if k == :vfun
            seen_vfun && argerr("@ARG_TEST duplicate keyword: vfun")
            vfun_expr = v
            seen_vfun = true
        elseif k == :vmsg
            seen_vmsg && argerr("@ARG_TEST duplicate keyword: vmsg")
            s = string_literal_value(v)
            s === nothing && argerr("@ARG_TEST vmsg must be a String literal")
            vmsg_text = s
            seen_vmsg = true
        else
            argerr("@ARG_TEST unknown keyword: $(k)")
        end
    end

    !isempty(names) || argerr("@ARG_TEST requires at least one argument name")
    ensure_no_duplicates!(names, "@ARG_TEST", "argument names")

    seen_vfun || argerr("@ARG_TEST requires vfun=...")
    seen_vmsg && !seen_vfun && argerr("@ARG_TEST vmsg requires vfun")

    for nm in names
        nm in ctx.declared_names || argerr("@ARG_TEST references unknown argument: $(nm)")

        kind = get(ctx.name_kind, nm, AK_OPTION)

        if kind in (AK_OPTION_MULTI, AK_POS_REST)
            push!(ctx.post_stmts, emit_stream_validator_stmt(
                nm, vfun_expr, vmsg_text, validator_default_message(:multi)
            ))
        elseif kind in (AK_OPTION, AK_POS_OPTIONAL)
            push!(ctx.post_stmts, emit_scalar_validator_stmt(
                nm, vfun_expr, vmsg_text, validator_default_message(:opt_optional); skip_nothing=true
            ))
        else
            push!(ctx.post_stmts, emit_scalar_validator_stmt(
                nm, vfun_expr, vmsg_text, validator_default_message(:opt_required); skip_nothing=false
            ))
        end
    end
end

function handle_arg_stream!(ctx::CompileCtx, node::Expr)
    length(node.args) >= 4 || argerr("@ARG_STREAM expects at least: @ARG_STREAM arg_name vfun=... [vmsg=\"...\"]")

    nm = expect_name_symbol(node.args[3], "@ARG_STREAM", "argument name")
    nm in ctx.declared_names || argerr("@ARG_STREAM references unknown argument: $(nm)")

    kind = get(ctx.name_kind, nm, AK_OPTION)
    kind in (AK_OPTION_MULTI, AK_POS_REST) ||
        argerr("@ARG_STREAM supports only streaming arguments (@ARG_MULTI / @POS_REST): $(nm)")

    vfun_expr = nothing
    vmsg_text = ""
    seen_vfun = false
    seen_vmsg = false

    for i in 4:length(node.args)
        a = node.args[i]
        p = kw_pair(a)
        p === nothing && argerr("@ARG_STREAM only supports keyword arguments: vfun=..., vmsg=\"...\"")
        kraw, v = p
        k = kw_key_symbol(kraw)
        k === nothing && argerr("@ARG_STREAM invalid keyword name: $(repr(kraw))")

        if k == :vfun
            seen_vfun && argerr("@ARG_STREAM duplicate keyword: vfun")
            vfun_expr = v
            seen_vfun = true
        elseif k == :vmsg
            seen_vmsg && argerr("@ARG_STREAM duplicate keyword: vmsg")
            s = string_literal_value(v)
            s === nothing && argerr("@ARG_STREAM vmsg must be a String literal")
            vmsg_text = s
            seen_vmsg = true
        else
            argerr("@ARG_STREAM unknown keyword: $(k)")
        end
    end

    seen_vfun || argerr("@ARG_STREAM requires vfun=...")
    seen_vmsg && !seen_vfun && argerr("@ARG_STREAM vmsg requires vfun")

    push!(ctx.post_stmts, emit_stream_validator_stmt(
        nm, vfun_expr, vmsg_text, validator_default_message(:multi)
    ))
end

const COMPILE_BLOCK_HANDLERS = Dict{Symbol,Function}(
    SYM_ARGREL_DEPENDS    => handle_argrel_depends!,
    SYM_ARGREL_CONFLICTS  => handle_argrel_conflicts!,
    SYM_ARGREL_ATMOSTONE  => handle_argrel_atmostone!,
    SYM_ARGREL_ATLEASTONE => handle_argrel_atleastone!,
    SYM_ARGREL_ONLYONE    => handle_argrel_onlyone!,
    SYM_ARGREL_ALLORNONE  => handle_argrel_allornone!,
    SYM_ARG_GROUP         => handle_arg_group!,
    SYM_TEST              => handle_arg_test!,
    SYM_STREAM            => handle_arg_stream!,
)

function compile_cmd_block(block::Expr)
    ctx = CompileCtx()
    for node in getmacrocalls(block)
        m = getmacroname(node)
        m === nothing && argerr("unsupported DSL macro expression")
        if haskey(ARG_DECL_SPECS, m)
            decl = parse_decl_pipeline!(ctx, ARG_DECL_SPECS[m], node)
            emit_decl_codegen!(ctx, decl)
        else
            h = get(COMPILE_BLOCK_HANDLERS, m, nothing)
            h === nothing && argerr("unsupported DSL macro: $(m)")
            h(ctx, node)
        end
    end
    validate_relations!(ctx)
    return ctx.fields, ctx.option_parse_stmts, ctx.positional_parse_stmts, ctx.post_stmts,
           ctx.argdefs_expr, ctx.relation_defs, ctx.arg_group_defs
end
