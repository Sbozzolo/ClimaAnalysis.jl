module Leaderboard

import OrderedCollections: OrderedDict
import NaNStatistics: nanmedian

export RMSEVariable,
    model_names,
    category_names,
    rmse_units,
    read_rmses,
    getindex,
    setindex!

"""
    Holding root mean squared errors over multiple categories and models for a single
    variable.
"""
struct RMSEVariable{
    FT <: AbstractFloat,
    S1 <: AbstractString,
    S2 <: AbstractString,
}
    "Short name of variable of interest"
    short_name::AbstractString

    "Map model name (like `CliMA`) to index"
    model2index::OrderedDict{S1, Int}

    "Map category name (like `ANN` and seasons) to index"
    category2index::OrderedDict{S2, Int}

    "Arrray of RMSEs (rows correspond to model names and columns correspond to categories)"
    RMSEs::Array{FT, 2}

    "Map model_name to units"
    units::Dict{S1, String}
end

"""
    RMSEVariable(short_name::String,
                 model_names::Vector{String},
                 category_names::Vector{String},
                 RMSEs,
                 units::Dict)

Construct a RMSEVariable with the `short_name` of the variable, the names of the models in
`model_names`, the categories in `category_names`, the root mean squared errors in `RMSEs`,
and `units`.
"""
function RMSEVariable(
    short_name::String,
    model_names::Vector{String},
    category_names::Vector{String},
    RMSEs,
    units::Dict,
)
    # Check if the dimensions of model_names and category_names match the dimensions of RMSE array
    (length(model_names), length(category_names)) != size(RMSEs) && error(
        "The size of RMSEs ($(size(RMSEs))) does not fit the number of model names ($(length(model_names))) and categories ($(length(category_names)))",
    )

    # Check if RMSE is negative
    any(RMSEs .< 0.0) && error("RMSEs cannot be negative")

    # Check for uniqueness
    length(unique(model_names)) == length(model_names) ||
        error("Model names are not unique")
    length(unique(category_names)) == length(category_names) ||
        error("Category names are not unique")
    model2index = OrderedDict(model_names |> enumerate |> collect .|> reverse)
    category2index =
        OrderedDict(category_names |> enumerate |> collect .|> reverse)

    # Add missing model_name and key in model_names so that each model present in
    # model_names is missing units or has an unit
    for model_name in model_names
        !haskey(units, model_name) && (units[model_name] = "")
    end

    # Delete model_name in units if they do not appear in model_names. We do not want to
    # have unnecessary units in the Dict
    for key in keys(units)
        !(key in model_names) && delete!(units, key)
    end

    # Check number of model to unit pairs match the number of models
    length(units) != length(model_names) && error(
        "The number of unit for each model ($length(units)) is not equal to the number of models ($length(model_names))",
    )
    return RMSEVariable(short_name, model2index, category2index, RMSEs, units)
end

"""
    RMSEVariable(short_name, model_names::Vector{String})

Construct a RMSEVariable with the `short_name` of the variable and the names of the
models in `model_names`.

The categories default to "ANN", "DJF", "MAM", "JJA", "SON". The root mean square errors
default to `NaN`. The unit for each model is missing which is denoted by an empty string.
"""
function RMSEVariable(short_name, model_names::Vector{String})
    category_names = ["ANN", "DJF", "MAM", "JJA", "SON"]
    RMSEs = fill(NaN, length(model_names), length(category_names))
    units = Dict{valtype(model_names), String}([
        (model_name, "") for model_name in model_names
    ])
    return RMSEVariable(short_name, model_names, category_names, RMSEs, units)
end

"""
    RMSEVariable(short_name, model_names::Vector{String}, units::Dict)

Construct a RMSEVariable with the `short_name` of the variable, the names of the models in
`model_names`, and provided units in the dictionary `units` that map model name to unit.

The categories default to "ANN", "DJF", "MAM", "JJA", "SON". The root mean square errors
default to `NaN`. Any missing model in the dictionary `units` will has missing unit which
is denoted by an empty string.
"""
function RMSEVariable(short_name, model_names::Vector{String}, units::Dict)
    category_names = ["ANN", "DJF", "MAM", "JJA", "SON"]
    RMSEs = fill(NaN, length(model_names), length(category_names))
    return RMSEVariable(short_name, model_names, category_names, RMSEs, units)
end

"""
    RMSEVariable(short_name,
                 model_names::Vector{String},
                 category_names::Vector{String},
                 units::Dict)

Construct a RMSEVariable with the `short_name` of the variable, the names of the models in
`model_names`, the categories in `category_names`, and provided units in the dictionary
`units` that map model name to unit.

The root mean square errors default to `NaN`. Any missing model in the dictionary `units`
will has missing unit which is denoted by an empty string.
"""
function RMSEVariable(
    short_name,
    model_names::Vector{String},
    category_names::Vector{String},
    units::Dict,
)
    RMSEs = fill(NaN, length(model_names), length(category_names))
    return RMSEVariable(short_name, model_names, category_names, RMSEs, units)
end

"""
    RMSEVariable(short_name::String,
                 model_names::Vector{String},
                 category_names::Vector{String},
                 RMSEs,
                 units::String)

Construct a RMSEVariable with the `short_name` of the variable, the names of the models in
`model_names`, the categories in `category_names`, the root mean squared errors in `RMSEs`,
and units which map each model name to `units`.

This is useful if all the models share the same unit.
"""
function RMSEVariable(
    short_name::String,
    model_names::Vector{String},
    category_names::Vector{String},
    RMSEs,
    units::String,
)
    units_dict = Dict(model_name => units for model_name in model_names)
    return RMSEVariable(
        short_name,
        model_names,
        category_names,
        RMSEs,
        units_dict,
    )
end

"""
    RMSEVariable(short_name, model_names::Vector{String}, units::String)

Construct a RMSEVariable with the `short_name` of the variable, the names of the models in
`model_names`, and units which map each model name to `units`.

The categories default to "ANN", "DJF", "MAM", "JJA", "SON". The root mean square errors
default to `NaN`.

This is useful if all the models share the same unit.
"""
function RMSEVariable(short_name, model_names::Vector{String}, units::String)
    units_dict = Dict(model_name => units for model_name in model_names)
    return RMSEVariable(short_name, model_names, units_dict)
end

"""
    RMSEVariable(short_name,
                 model_names::Vector{String},
                 category_names::Vector{String},
                 units::String)

Construct a RMSEVariable with the `short_name` of the variable, the names of the models in
`model_names`, the categories in `category_names`, and units which map each model name to
`units`.

The root mean square errors default to `NaN`.

This is useful if all the models share the same unit.
"""
function RMSEVariable(
    short_name,
    model_names::Vector{String},
    category_names::Vector{String},
    units::String,
)
    RMSEs = fill(NaN, length(model_names), length(category_names))
    return RMSEVariable(short_name, model_names, category_names, RMSEs, units)
end

"""
    model_names(rmse_var::RMSEVariable)

Return all the model names in `rmse_var`.
"""
model_names(rmse_var::RMSEVariable) = rmse_var.model2index |> keys |> collect

"""
    category_names(rmse_var::RMSEVariable)

Return all the category names in `rmse_var`.
"""
category_names(rmse_var::RMSEVariable) =
    rmse_var.category2index |> keys |> collect

"""
    rmse_units(rmse_var::RMSEVariable)

Return all the unit of the models in `rmse_var`.
"""
rmse_units(rmse_var::RMSEVariable) = rmse_var.units

"""
    read_rmses(csv_file::String, short_name::String; units = nothing)

Read a CSV file and create a RMSEVariable with the `short_name` of the variable.

The format of the CSV file should have a header consisting of the entry "model_name" (or any
other text as it is ignored by the function) and rest of the entries should be the category
names. Each row after the header should start with the model name and the root mean squared
errors for each category for that model. The entries of the CSV file should be separated by
commas.

The parameter `units` can be a dictionary mapping model name to unit or a string. If `units`
is a string, then units will be the same across all models. If units is `nothing`, then the
unit is missing for each model which is denoted by an empty string.
"""
function read_rmses(csv_file::String, short_name::String; units = nothing)
    # Intialize variables we need to construct RMSEVariable
    model_names = Vector{String}()
    model_rmse_vec = []
    category_names = nothing
    open(csv_file, "r") do io
        header = readline(io)
        # Get categories (e.g. DJF, MAM, JJA, SON, ANN)
        category_names = String.(split(header, ','))

        # get rid of the first column name which is the column named "model_name"
        category_names |> popfirst!

        # Process each line
        for (line_num, line) in enumerate(eachline(io))
            # Split the line by comma
            fields = split(line, ',')

            # Check if any entry is missing in the CSV file
            length(fields) != (length(category_names) + 1) &&
                error("Missing RMSEs for line $(line_num + 1) in CSV file")

            # Grab model name
            model_name = fields[1]

            # the rest of the row is the rmse for each category
            model_rmse = map(x -> parse(Float64, x), fields[2:end])

            push!(model_names, model_name)
            push!(model_rmse_vec, model_rmse)
        end
    end
    model_rmses = stack(model_rmse_vec, dims = 1)
    isnothing(units) && (
        units = Dict{valtype(model_names), String}([
            (model_name, "") for model_name in model_names
        ])
    )
    units isa String && (
        units = Dict{valtype(model_names), String}([
            model_name => units for model_name in model_names
        ])
    )
    return RMSEVariable(
        short_name,
        model_names,
        category_names,
        model_rmses,
        units,
    )
end

"""
    function _index_convert(key2index, key::Colon)

Convert the symbol colon into an index for indexing.
"""
function _index_convert(key2index, key::Colon)
    return collect(values(key2index))
end

"""
    function _index_convert(key2index,
                            indices::AbstractVector{I})
                            where {I <: Integer}

Convert a string into an index for indexing.
"""
function _index_convert(key2index, key::AbstractString)
    !haskey(key2index, key) &&
        error("Key ($key) is not present in ($(keys(key2index)))")
    return key2index[key]
end

"""
    function _index_convert(key2index,
                            keys::AbstractVector{S})
                            where {S <: AbstractString}

Convert a vector of strings to indices for indexing.
"""
function _index_convert(
    key2index,
    keys::AbstractVector{S},
) where {S <: AbstractString}
    for key in keys
        !haskey(key2index, key) &&
            error("Key ($key) is not present in ($(keys(key2index)))")
    end
    return [key2index[key] for key in keys]
end

"""
    function _index_convert(key2index,
                            indices::AbstractVector{I})
                            where {I <: Integer}

Convert an integer to an index for indexing.
"""
function _index_convert(key2index, index::Integer)
    !(index in values(key2index)) &&
        error("Index ($index) is not present in ($(values(key2index)))")
    return index
end

"""
    function _index_convert(key2index,
                            indices::AbstractVector{I})
                            where {I <: Integer}

Convert a vector of integers to indices for indexing.
"""
function _index_convert(
    key2index,
    indices::AbstractVector{I},
) where {I <: Integer}
    for index in indices
        !(index in values(key2index)) &&
            error("Index ($index) is not present in ($(values(key2index)))")
    end
    return indices
end

"""
    Base.getindex(rmse_var::RMSEVariable, model_name, category)

Return a subset of the array holding the root mean square errors as specified by
`model_name` and `category`. Support indexing by `String` and `Int`.
"""
function Base.getindex(rmse_var::RMSEVariable, model_name, category)
    model_idx = _index_convert(rmse_var.model2index, model_name)
    cat_idx = _index_convert(rmse_var.category2index, category)
    return rmse_var.RMSEs[model_idx, cat_idx]
end

"""
    Base.getindex(rmse_var::RMSEVariable, model_name::String)

Return a subset of the array holding the root mean square errors as specified by
`model_name`. Support indexing by `String`. Do not support linear indexing.
"""
function Base.getindex(rmse_var::RMSEVariable, model_name::String)
    return rmse_var[model_name, :]
end

"""
    Base.setindex!(rmse_var::RMSEVariable, rmse, model_name, category)

Store a value or values from an array in the array of root mean squared errors in
`rmse_var`. Support indexing by `String` and `Int`.
"""
function Base.setindex!(rmse_var::RMSEVariable, rmse, model_name, category)
    model_idx = _index_convert(rmse_var.model2index, model_name)
    cat_idx = _index_convert(rmse_var.category2index, category)
    rmse_var.RMSEs[model_idx, cat_idx] = rmse
end

"""
    Base.setindex!(rmse_var::RMSEVariable, rmse, model_name::String)

Store a value or values from an array into the array of root mean squared errors in
`rmse_var`. Support indexing by `String`. Do not support linear indexing.
"""
function Base.setindex!(rmse_var::RMSEVariable, rmse, model_name::String)
    model_idx = _index_convert(rmse_var.model2index, model_name)
    rmse_var.RMSEs[model_idx, :] = rmse
end

end