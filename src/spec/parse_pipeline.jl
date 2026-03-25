const PARSE_PIPELINE_STAGES = (
    :normalize_ast,
    :parse_meta,
    :parse_declarations,
    :semantic_validation,
    :build_ir,
    :emit_parser_code
)
