Base.@kwdef struct ArgDeclSpec
    macro_name::String
    kind::ArgKind
    style::Symbol
    has_type::Bool
    require_flags::Bool
    allow_default::Bool
    allow_env::Bool
    allow_fallback::Bool
end

const ARG_DECL_SPECS = Dict{Symbol,ArgDeclSpec}(
    SYM_REQ     => ArgDeclSpec(macro_name="@ARG_REQ",   kind=AK_OPTION,       style=:opt_required, has_type=true,  require_flags=true,  allow_default=false, allow_env=false, allow_fallback=false),
    SYM_OPT     => ArgDeclSpec(macro_name="@ARG_OPT",   kind=AK_OPTION,       style=:opt_optional, has_type=true,  require_flags=true,  allow_default=true,  allow_env=true,  allow_fallback=true),
    SYM_FLAG    => ArgDeclSpec(macro_name="@ARG_FLAG",  kind=AK_FLAG,         style=:flag,         has_type=false, require_flags=true,  allow_default=false, allow_env=false, allow_fallback=false),
    SYM_COUNT   => ArgDeclSpec(macro_name="@ARG_COUNT", kind=AK_COUNT,        style=:count,        has_type=false, require_flags=true,  allow_default=false, allow_env=false, allow_fallback=false),
    SYM_MULTI   => ArgDeclSpec(macro_name="@ARG_MULTI", kind=AK_OPTION_MULTI, style=:multi,        has_type=true,  require_flags=true,  allow_default=false, allow_env=false, allow_fallback=false),

    SYM_POS_REQ => ArgDeclSpec(macro_name="@POS_REQ",   kind=AK_POS_REQUIRED, style=:pos_required, has_type=true,  require_flags=false, allow_default=false, allow_env=false, allow_fallback=false),
    SYM_POS_OPT => ArgDeclSpec(macro_name="@POS_OPT",   kind=AK_POS_OPTIONAL, style=:pos_optional, has_type=true,  require_flags=false, allow_default=true,  allow_env=true,  allow_fallback=true),
    SYM_POS_RST => ArgDeclSpec(macro_name="@POS_REST",  kind=AK_POS_REST,     style=:pos_rest,     has_type=true,  require_flags=false, allow_default=false, allow_env=false, allow_fallback=false),
)

mutable struct CompileCtx
    fields::Vector{Expr}
    option_parse_stmts::Vector{Expr}
    positional_parse_stmts::Vector{Expr}
    post_stmts::Vector{Expr}
    argdefs_expr::Vector{Expr}
    relation_defs::Vector{ArgRelationDef}
    arg_group_defs::Vector{ArgGroupDef}
    fallback_map::Dict{Symbol,Symbol}
    declared_names::Set{Symbol}
    name_kind::Dict{Symbol,ArgKind}
    seen_pos_rest::Bool
    flag_owner::Dict{String,Symbol}
end

CompileCtx() = CompileCtx(
    Expr[], Expr[], Expr[], Expr[], Expr[],
    ArgRelationDef[],
    ArgGroupDef[],
    Dict{Symbol,Symbol}(),
    Set{Symbol}(), Dict{Symbol,ArgKind}(),
    false, Dict{String,Symbol}()
)

Base.@kwdef struct NormalizedSubCmd
    name::String
    description::String = ""
    usage::String = ""
    epilog::String = ""
    version::String = ""
    block::Expr
    allow_extra::Bool = false
    auto_help::Bool = false
end
