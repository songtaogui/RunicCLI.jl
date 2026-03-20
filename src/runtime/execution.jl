@inline function _throw_arg_error(msg::String)
    throw(ArgParseError(msg))
end

@inline function _throw_arg_error_ctx(name::AbstractString, expected::AbstractString, got; hint::AbstractString="")
    g = repr(got)
    msg = "Invalid value for $(name): expected $(expected), got $(g)"
    if !isempty(hint)
        msg *= ". " * String(hint)
    end
    throw(ArgParseError(msg))
end

# ---- message templates ----
@inline _msg_option_requires_value(opt::AbstractString) =
    "Option $(opt) requires a value"

@inline _msg_option_disallow_empty_value(opt::AbstractString) =
    "Option $(opt) does not allow empty value (use an explicit non-empty value)"

@inline _msg_option_value_is_option(opt::AbstractString, val::AbstractString) =
    "Option $(opt) requires a value, but got another option token: $(val)"

@inline _msg_option_specified_multiple(flag::AbstractString, name::AbstractString) =
    "Option $(flag) specified multiple times for $(name)"

@inline _msg_missing_required_option(flag::AbstractString) =
    "Missing required option $(flag)"

@inline _msg_missing_required_positional(name::AbstractString) =
    "Missing required positional $(name)"

@inline _msg_unknown_or_unexpected_option(tok::AbstractString) =
    "Unknown or unexpected option: $(tok)"

@inline function _msg_unknown_or_unexpected_arguments(args::Vector{String}, hint::AbstractString="")
    msg = "Unknown or unexpected arguments: " * join(args, " ")
    if !isempty(hint)
        msg *= hint
    end
    return msg
end

@inline function _msg_mutually_exclusive_args(names::Vector{String}, details::Vector{String})
    "Mutually exclusive arguments provided together: " * join(names, ", ") * ". Details: " * join(details, "; ")
end

@inline _msg_at_least_one_required(names::Vector{String}) =
    "At least one of the following arguments must be provided: " * join(names, ", ")

@inline _msg_arg_requires(anchor::AbstractString, targets::Vector{String}) =
    "Argument $(anchor) requires at least one of: " * join(targets, ", ")

@inline _msg_arg_conflicts(anchor::AbstractString, hits::Vector{String}) =
    "Argument $(anchor) conflicts with: " * join(hits, ", ")

    @inline _msg_invalid_short_option_bundle_non_ascii(s::AbstractString) =
    "Invalid short option bundle (non-ASCII): $(s)"

@inline _msg_invalid_short_option_bundle(s::AbstractString) =
    "Invalid short option bundle: $(s)"

@inline _msg_ambiguous_short_bundle_with_equals(arg::AbstractString) =
    "Ambiguous short bundle with '=' is not allowed: $(arg). Use '-a -b -c' or '--long=value'."

@inline _msg_bundle_option_requiring_value_must_be_last(tok::AbstractString) =
    "Invalid short option bundle: option requiring value must be last in bundle: $(tok)"
