using Test
import ClimaAnalysis

import Interpolations as Intp
import NaNStatistics: nanmean
import NCDatasets: NCDataset
import OrderedCollections: OrderedDict
import Unitful: @u_str

@testset "General" begin
    # Add test for short constructor
    long = -180.0:180.0 |> collect
    data = copy(long)

    longvar = ClimaAnalysis.OutputVar(Dict("long" => long), data)

    @test longvar.dims["long"] == long

    # Unitful
    attribs = Dict("long_name" => "hi", "units" => "m/s")
    dim_attributes = OrderedDict(["long" => Dict("units" => "m")])

    var_with_unitful = ClimaAnalysis.OutputVar(
        attribs,
        Dict("long" => long),
        dim_attributes,
        data,
    )

    @test ClimaAnalysis.units(var_with_unitful) == "m s^-1"
    @test var_with_unitful.attributes["units"] == u"m" / u"s"

    # Unparsable unit
    attribs = Dict("long_name" => "hi", "units" => "bob")
    var_without_unitful = ClimaAnalysis.OutputVar(
        attribs,
        Dict("long" => long),
        dim_attributes,
        data,
    )

    @test ClimaAnalysis.units(var_without_unitful) == "bob"
    @test var_without_unitful.attributes["units"] == "bob"

    # Reading directly from file
    ncpath = joinpath(@__DIR__, "topo_drag.res.nc")
    file_var = ClimaAnalysis.OutputVar(ncpath, "t11")
    NCDataset(ncpath) do nc
        @test nc["t11"][:, :, :] == file_var.data
    end

    # center_longitude!
    #
    # Check var without long
    dims = Dict("z" => long)
    var_error = ClimaAnalysis.OutputVar(
        Dict{String, Any}(),
        dims,
        Dict{String, Any}(),
        data,
    )
    @test_throws ErrorException ClimaAnalysis.center_longitude!(
        var_error,
        180.0,
    )

    time = 0:10.0 |> collect
    dims = OrderedDict("lon" => long, "time" => time)
    data = collect(reshape(1:(361 * 11), (361, 11)))
    var_good = ClimaAnalysis.OutputVar(
        Dict{String, Any}(),
        dims,
        Dict{String, Any}(),
        data,
    )
    ClimaAnalysis.center_longitude!(var_good, 90.0)
    # We are shifting by 91
    @test var_good.dims["lon"][180] == 90
    @test var_good.data[3, :] == data[3, :]
    @test var_good.data[180, 1] == 271

    @test_throws ErrorException ClimaAnalysis.OutputVar(
        Dict("time" => time),
        [1],
    )
end

@testset "Arithmetic operations" begin
    long = 0.0:180.0 |> collect
    lat = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect

    data1 = collect(reshape(1.0:(91 * 181 * 11), (11, 181, 91)))

    dims = OrderedDict(["time" => time, "lon" => long, "lat" => lat])
    dim_attributes = OrderedDict([
        "time" => Dict(),
        "lon" => Dict("b" => 2),
        "lat" => Dict("a" => 1),
    ])
    attribs = Dict("short_name" => "bob", "long_name" => "hi")
    var1 = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data1)

    dim_attributes2 = OrderedDict([
        "time" => Dict(),
        "lon" => Dict("lol" => 2),
        "lat" => Dict("a" => 1),
    ])

    var2 = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes2, data1)

    data3 = 5.0 .+ collect(reshape(1.0:(91 * 181 * 11), (11, 181, 91)))
    attribs3 = Dict("long_name" => "bob", "short_name" => "bula")
    var3 = ClimaAnalysis.OutputVar(attribs3, dims, dim_attributes, data3)

    # Check arecompatible
    @test !ClimaAnalysis.arecompatible(var1, var2)
    @test ClimaAnalysis.arecompatible(var1, var3)

    var1plus10 = var1 + 10

    @test var1plus10.data == data1 .+ 10
    @test ClimaAnalysis.short_name(var1plus10) == "bob + 10"
    @test ClimaAnalysis.long_name(var1plus10) == "hi + 10"

    tenplusvar1 = 10 + var1

    @test tenplusvar1.data == data1 .+ 10
    @test ClimaAnalysis.short_name(tenplusvar1) == "10 + bob"
    @test ClimaAnalysis.long_name(tenplusvar1) == "10 + hi"

    var1plusvar3 = var1 + var3

    @test var1plusvar3.data == data1 .+ data3
    @test ClimaAnalysis.short_name(var1plusvar3) == "bob + bula"
    @test ClimaAnalysis.long_name(var1plusvar3) == "hi + bob"
end

@testset "Reductions (sphere dims)" begin
    long = 0.0:180.0 |> collect
    lat = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect

    data = collect(reshape(1.0:(91 * 181 * 11), (11, 181, 91)))

    dims = OrderedDict(["time" => time, "lon" => long, "lat" => lat])
    dim_attributes = OrderedDict([
        "time" => Dict(),
        "lon" => Dict("b" => 2),
        "lat" => Dict("a" => 1),
    ])
    attribs = Dict("long_name" => "hi")
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    # Test copy
    var_copied = copy(var)
    fields = fieldnames(ClimaAnalysis.OutputVar)
    for field in fields
        @test getfield(var, field) == getfield(var_copied, field)
        @test getfield(var, field) !== getfield(var_copied, field)
    end

    # Test reduction
    lat_avg = ClimaAnalysis.average_lat(var)
    @test lat_avg.dims == OrderedDict(["lon" => long, "time" => time])
    @test lat_avg.dim_attributes ==
          OrderedDict(["lon" => Dict("b" => 2), "time" => Dict()])
    @test lat_avg.data == dropdims(nanmean(data, dims = 3), dims = 3)

    wei_lat_avg = ClimaAnalysis.weighted_average_lat(var)
    @test wei_lat_avg.dims == OrderedDict(["lon" => long, "time" => time])
    @test wei_lat_avg.dim_attributes ==
          OrderedDict(["lon" => Dict("b" => 2), "time" => Dict()])
    weights = ones(size(data))
    for i in eachindex(time)
        for j in eachindex(long)
            for k in eachindex(lat)
                weights[i, j, k] = cosd(lat[k])
            end
        end
    end
    weights ./= nanmean(cosd.(lat))
    expected_avg = dropdims(nanmean(data .* weights, dims = 3), dims = 3)
    @test wei_lat_avg.data ≈ expected_avg

    # Test reduction with NaN
    latnan = [1, 2, 3]
    datanan = [10.0, 20.0, NaN]

    dimsnan = OrderedDict(["lat" => latnan])
    dim_attributesnan = OrderedDict(["lat" => Dict("b" => 2)])
    attribsnan = Dict("lat_name" => "hi")
    varnan =
        ClimaAnalysis.OutputVar(attribsnan, dimsnan, dim_attributesnan, datanan)
    @test isnan(ClimaAnalysis.average_lat(varnan; ignore_nan = false).data[])
    @test ClimaAnalysis.average_lat(varnan; weighted = true).data[] ≈
          (datanan[1] * cosd(latnan[1]) + datanan[2] * cosd(latnan[2])) /
          (cosd(latnan[1]) + cosd(latnan[2]))

    wrong_dims = OrderedDict(["lat" => [0.0, 0.1]])
    wrong_dim_attributes = OrderedDict(["lat" => Dict("a" => 1)])
    wrong_var = ClimaAnalysis.OutputVar(
        Dict{String, Any}(),
        wrong_dims,
        wrong_dim_attributes,
        [0.0, 0.1],
    )
    @test_logs (
        :warn,
        "Detected latitudes are small. If units are radians, results will be wrong",
    )

    lat_lon_avg = ClimaAnalysis.average_lon(lat_avg)
    @test lat_lon_avg.dims == OrderedDict(["time" => time])
    @test lat_lon_avg.dim_attributes == OrderedDict(["time" => Dict()])

    @test lat_lon_avg.data ==
          dropdims(nanmean(lat_avg.data, dims = 2), dims = 2)

    lat_lon_time_avg = ClimaAnalysis.average_time(lat_lon_avg)
    @test lat_lon_time_avg.dims == OrderedDict()
    @test lat_lon_time_avg.dim_attributes == OrderedDict()

    @test lat_lon_time_avg.data[] == nanmean(data)

    @test lat_lon_time_avg.attributes["long_name"] ==
          "hi averaged over lat (0.0 to 90.0) averaged over lon (0.0 to 180.0) averaged over time (0.0 to 10.0)"
end

@testset "Reductions (box dims)" begin
    x = 0.0:180.0 |> collect
    y = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect

    data = reshape(1.0:(91 * 181 * 11), (11, 181, 91))

    # Identical test pattern to sphere setup, with `dims` modified.
    dims = OrderedDict(["time" => time, "x" => x, "y" => y])
    dim_attributes = OrderedDict([
        "time" => Dict(),
        "x" => Dict("b" => 2),
        "y" => Dict("a" => 1),
    ])
    attribs = Dict("long_name" => "hi")
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    y_avg = ClimaAnalysis.average_y(var)
    @test y_avg.dims == OrderedDict(["x" => x, "time" => time])
    @test y_avg.dim_attributes ==
          OrderedDict(["x" => Dict("b" => 2), "time" => Dict()])
    @test y_avg.data == dropdims(nanmean(data, dims = 3), dims = 3)

    y_x_avg = ClimaAnalysis.average_x(y_avg)
    xy_avg = ClimaAnalysis.average_xy(var)
    @test y_x_avg.data == xy_avg.data
    @test y_x_avg.dims == OrderedDict(["time" => time])
    @test y_x_avg.dim_attributes == OrderedDict(["time" => Dict()])

    @test y_x_avg.data == dropdims(nanmean(y_avg.data, dims = 2), dims = 2)

    y_x_time_avg = ClimaAnalysis.average_time(y_x_avg)
    xy_time_avg = ClimaAnalysis.average_time(xy_avg)
    @test y_x_time_avg.dims == OrderedDict()
    @test y_x_time_avg.dim_attributes == OrderedDict()

    @test y_x_time_avg.data[] == nanmean(data)

    @test y_x_time_avg.attributes["long_name"] ==
          "hi averaged over y (0.0 to 90.0) averaged over x (0.0 to 180.0) averaged over time (0.0 to 10.0)"

    @test xy_time_avg.attributes["long_name"] ==
          "hi averaged horizontally over x (0.0 to 180.0) and y (0.0 to 90.0) averaged over time (0.0 to 10.0)"
end

@testset "Slicing" begin
    z = 0.0:20.0 |> collect
    time = 100.0:110.0 |> collect

    data = reshape(1.0:(11 * 21), (11, 21))

    dims = OrderedDict(["time" => time, "z" => z])
    dim_attributes =
        OrderedDict(["time" => Dict("units" => "s"), "z" => Dict("b" => 2)])
    attribs = Dict("long_name" => "hi")
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    z_sliced = ClimaAnalysis.slice(var, z = 1.0)
    # 1.0 is the second index
    z_expected_data = data[:, 2]
    @test z_sliced.dims == OrderedDict(["time" => time])
    @test z_sliced.dim_attributes ==
          OrderedDict(["time" => Dict("units" => "s")])
    @test z_sliced.data == z_expected_data

    t_sliced = ClimaAnalysis.slice(var, time = 200.0)
    # 200 is the last index
    t_expected_data = data[end, :]
    @test t_sliced.dims == OrderedDict(["z" => z])
    @test t_sliced.dim_attributes == OrderedDict(["z" => Dict("b" => 2)])
    @test t_sliced.data == t_expected_data

    @test t_sliced.attributes["long_name"] == "hi time = 1m 50.0s"

    # Test with the general slice

    t_sliced = ClimaAnalysis.slice(var, time = 200.0)
    # 200 is the last index
    t_expected_data = data[end, :]
    @test t_sliced.dims == OrderedDict(["z" => z])
    @test t_sliced.dim_attributes == OrderedDict(["z" => Dict("b" => 2)])
    @test t_sliced.data == t_expected_data

    @test t_sliced.attributes["long_name"] == "hi time = 1m 50.0s"

    @test t_sliced.attributes["slice_time"] == "110.0"
    @test t_sliced.attributes["slice_time_units"] == "s"
end

@testset "Windowing" begin
    z = 0.0:20.0 |> collect
    time = 0.0:10.0 |> collect

    data = reshape(1.0:(11 * 21), (11, 21))

    dims = OrderedDict(["time" => time, "z" => z])
    dim_attributes =
        OrderedDict(["time" => Dict("units" => "s"), "z" => Dict("b" => 2)])
    attribs = Dict("long_name" => "hi")
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    # Dimension not existing
    @test_throws ErrorException ClimaAnalysis.window(var, "lat")

    # Left right not ordered
    @test_throws ErrorException ClimaAnalysis.window(
        var,
        "time",
        left = 10,
        right = 1,
    )

    var_windowed = ClimaAnalysis.window(var, "time", left = 2.5, right = 5.1)
    expected_data = data[3:6, :]

    @test var_windowed.data == expected_data

    @test var_windowed.dims["time"] == time[3:6]
end

@testset "Extracting dimension" begin
    @test ClimaAnalysis.Var.find_dim_name(["a", "b"], ["c", "a"]) == "a"
    @test_throws ErrorException ClimaAnalysis.Var.find_dim_name(
        ["a", "b"],
        ["c", "d"],
    )

    long = 0.0:180.0 |> collect
    lat = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect
    alt = 0.0:2.0 |> collect

    data = reshape(1.0:(3 * 91 * 181 * 11), (11, 181, 91, 3))

    dims =
        OrderedDict(["time" => time, "lon" => long, "lat" => lat, "z" => alt])
    attribs = Dict("short_name" => "bob", "long_name" => "hi")
    dim_attributes = OrderedDict([
        "time" => Dict(),
        "lon" => Dict("b" => 2),
        "lat" => Dict("a" => 1),
        "z" => Dict(),
    ])
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    @test ClimaAnalysis.time_name(var) == "time"
    @test ClimaAnalysis.longitude_name(var) == "lon"
    @test ClimaAnalysis.latitude_name(var) == "lat"
    @test ClimaAnalysis.altitude_name(var) == "z"
    @test ClimaAnalysis.times(var) == time
    @test ClimaAnalysis.latitudes(var) == lat
    @test ClimaAnalysis.longitudes(var) == long
    @test ClimaAnalysis.altitudes(var) == alt
    @test ClimaAnalysis.has_time(var)
    @test ClimaAnalysis.has_longitude(var)
    @test ClimaAnalysis.has_latitude(var)
    @test ClimaAnalysis.has_altitude(var)
    @test ClimaAnalysis.conventional_dim_name("long") == "longitude"
    @test ClimaAnalysis.conventional_dim_name("latitude") == "latitude"
    @test ClimaAnalysis.conventional_dim_name("t") == "time"
    @test ClimaAnalysis.conventional_dim_name("date") == "date"
    @test ClimaAnalysis.conventional_dim_name("z") == "altitude"
    @test ClimaAnalysis.conventional_dim_name("hi") == "hi"
end

@testset "Interpolation" begin
    # 1D interpolation with linear data, should yield correct results
    long = -180.0:180.0 |> collect
    data = copy(long)

    longvar = ClimaAnalysis.OutputVar(Dict("long" => long), data)

    @test longvar.([10.5, 20.5]) == [10.5, 20.5]

    # Test error for data outside of range
    @test_throws BoundsError longvar(200.0)

    # 2D interpolation with linear data, should yield correct results
    time = 100.0:110.0 |> collect
    z = 0.0:20.0 |> collect

    data = reshape(1.0:(11 * 21), (11, 21))
    var2d = ClimaAnalysis.OutputVar(Dict("time" => time, "z" => z), data)
    @test var2d.([[105.0, 10.0], [105.5, 10.5]]) == [116.0, 122]
end

@testset "Dim of units and range" begin
    x = 0.0:180.0 |> collect
    y = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect
    data = collect(reshape(1.0:(91 * 181 * 11), (11, 181, 91)))

    dims = OrderedDict(["time" => time, "x" => x, "y" => y])
    dim_attributes = OrderedDict([
        "time" => Dict("units" => "seconds"),
        "x" => Dict("units" => "km"),
    ])
    attribs = Dict("long_name" => "hi")
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    @test ClimaAnalysis.dim_units(var, "y") == ""
    @test ClimaAnalysis.dim_units(var, "x") == "km"
    @test ClimaAnalysis.range_dim(var, "x") == (0.0, 180.0)
    @test_throws ErrorException(
        "Var does not have dimension z, found [\"time\", \"x\", \"y\"]",
    ) ClimaAnalysis.dim_units(var, "z")
    @test_throws ErrorException(
        "Var does not have dimension z, found [\"time\", \"x\", \"y\"]",
    ) ClimaAnalysis.range_dim(var, "z")
end

@testset "Long name updates" begin
    # Setup to test x_avg, y_avg, xy_avg  
    x = 0.0:180.0 |> collect
    y = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect
    data = collect(reshape(1.0:(91 * 181 * 11), (11, 181, 91)))

    dims = OrderedDict(["time" => time, "x" => x, "y" => y])
    dim_attributes = OrderedDict([
        "time" => Dict("units" => "seconds"),
        "x" => Dict("units" => "km"),
        "y" => Dict("units" => "km"),
    ])
    attribs = Dict("long_name" => "hi")
    var = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data)

    y_avg = ClimaAnalysis.average_y(var)
    @test y_avg.attributes["long_name"] == "hi averaged over y (0.0 to 90.0km)"

    x_avg = ClimaAnalysis.average_x(var)
    @test x_avg.attributes["long_name"] == "hi averaged over x (0.0 to 180.0km)"

    xy_avg = ClimaAnalysis.average_xy(var)
    @test xy_avg.attributes["long_name"] ==
          "hi averaged horizontally over x (0.0 to 180.0km) and y (0.0 to 90.0km)"

    # Setup to test average_lat and average_lon 
    long = 0.0:180.0 |> collect
    lat = 0.0:90.0 |> collect
    time = 0.0:10.0 |> collect

    data1 = collect(reshape(1.0:(91 * 181 * 11), (11, 181, 91)))

    dims = OrderedDict(["time" => time, "lon" => long, "lat" => lat])
    dim_attributes = OrderedDict([
        "time" => Dict("units" => "seconds"),
        "lon" => Dict("units" => "test_units1"),
        "lat" => Dict("units" => "test_units2"),
    ])
    attribs = Dict("long_name" => "hi")
    var1 = ClimaAnalysis.OutputVar(attribs, dims, dim_attributes, data1)

    lat_avg = ClimaAnalysis.average_lat(var1)
    lon_avg = ClimaAnalysis.average_lon(var1)
    lat_weighted_avg = ClimaAnalysis.weighted_average_lat(var1)

    @test lon_avg.attributes["long_name"] ==
          "hi averaged over lon (0.0 to 180.0test_units1)"
    @test lat_avg.attributes["long_name"] ==
          "hi averaged over lat (0.0 to 90.0test_units2)"
    @test lat_weighted_avg.attributes["long_name"] ==
          "hi weighted averaged over lat (0.0 to 90.0test_units2)"
end

@testset "Consistent units checking" begin
    x_long = 0.0:180.0 |> collect
    x_lat = 0.0:90.0 |> collect
    x_data = reshape(1.0:(181 * 91), (181, 91))
    x_dims = OrderedDict(["long" => x_long, "lat" => x_lat])
    x_attribs = Dict("long_name" => "hi")
    x_dim_attribs = OrderedDict([
        "long" => Dict("units" => "test_units1"),
        "lat" => Dict("units" => "test_units2"),
    ])
    x_var = ClimaAnalysis.OutputVar(x_attribs, x_dims, x_dim_attribs, x_data)

    y_lon = 0.0:90.0 |> collect
    y_lat = 0.0:45.0 |> collect
    y_data = reshape(1.0:(91 * 46), (91, 46))
    y_dims = OrderedDict(["lon" => y_lon, "lat" => y_lat])
    y_attribs = Dict("long_name" => "hi")
    y_dim_attribs = OrderedDict([
        "lon" => Dict("units" => "test_units1"),
        "lat" => Dict("units" => "test_units2"),
    ])
    y_var = ClimaAnalysis.OutputVar(y_attribs, y_dims, y_dim_attribs, y_data)
    @test_nowarn ClimaAnalysis.Var._check_dims_consistent(x_var, y_var)

    # Test if units are consistent between dimensions
    x_dim_attribs = OrderedDict([
        "long" => Dict("units" => "test_units2"),
        "lat" => Dict("units" => "test_units1"),
    ])
    x_var = ClimaAnalysis.OutputVar(x_attribs, x_dims, x_dim_attribs, x_data)
    @test_throws "Units for dimensions [\"long\", \"lat\"] in x is not consistent with units for dimensions [\"lon\", \"lat\"] in y" ClimaAnalysis.Var._check_dims_consistent(
        x_var,
        y_var,
    )

    # Test if units are missing from any of the dimensions
    x_dim_attribs = OrderedDict([
        "long" => Dict("units" => "test_units2"),
        "lat" => Dict("units" => ""),
    ])
    x_var = ClimaAnalysis.OutputVar(x_attribs, x_dims, x_dim_attribs, x_data)
    @test_throws "Units for dimensions [\"lat\"] are missing in x and units for dimensions [\"lat\"] are missing in y" ClimaAnalysis.Var._check_dims_consistent(
        x_var,
        x_var,
    )
    @test_throws "Units for dimensions [\"lat\"] are missing in x" ClimaAnalysis.Var._check_dims_consistent(
        x_var,
        y_var,
    )
    @test_throws "Units for dimensions [\"lat\"] are missing in y" ClimaAnalysis.Var._check_dims_consistent(
        y_var,
        x_var,
    )

    # Test if type of dimensions agree
    x_data = reshape(1.0:(91 * 181), (91, 181))
    x_dims = OrderedDict(["lat" => x_lat, "long" => x_long])
    x_dim_attribs = OrderedDict([
        "lat" => Dict("units" => "test_units1"),
        "long" => Dict("units" => "test_units2"),
    ])
    x_var = ClimaAnalysis.OutputVar(x_attribs, x_dims, x_dim_attribs, x_data)
    @test_throws "Dimensions do not agree between x ([\"latitude\", \"longitude\"]) and y ([\"longitude\", \"latitude\"])" ClimaAnalysis.Var._check_dims_consistent(
        x_var,
        y_var,
    )

    # Test number of dimensions are the same
    x_data = reshape(1.0:(181), (181))
    x_dims = OrderedDict(["long" => x_long])
    x_attribs = Dict("long_name" => "hi")
    x_dim_attribs = OrderedDict(["long" => Dict("units" => "test_units1")])
    x_var = ClimaAnalysis.OutputVar(x_attribs, x_dims, x_dim_attribs, x_data)
    @test_throws "Number of dimensions do not match between x (1) and y (2)" ClimaAnalysis.Var._check_dims_consistent(
        x_var,
        y_var,
    )

end

@testset "Resampling" begin
    src_long = 0.0:180.0 |> collect
    src_lat = 0.0:90.0 |> collect
    src_data = reshape(1.0:(181 * 91), (181, 91))
    src_dims = OrderedDict(["long" => src_long, "lat" => src_lat])
    src_attribs = Dict("long_name" => "hi")
    src_dim_attribs = OrderedDict([
        "long" => Dict("units" => "test_units1"),
        "lat" => Dict("units" => "test_units2"),
    ])
    src_var = ClimaAnalysis.OutputVar(
        src_attribs,
        src_dims,
        src_dim_attribs,
        src_data,
    )

    dest_long = 0.0:90.0 |> collect
    dest_lat = 0.0:45.0 |> collect
    dest_data = reshape(1.0:(91 * 46), (91, 46))
    dest_dims = OrderedDict(["long" => dest_long, "lat" => dest_lat])
    dest_attribs = Dict("long_name" => "hi")
    dest_dim_attribs = OrderedDict([
        "long" => Dict("units" => "test_units1"),
        "lat" => Dict("units" => "test_units2"),
    ])
    dest_var = ClimaAnalysis.OutputVar(
        dest_attribs,
        dest_dims,
        dest_dim_attribs,
        dest_data,
    )

    @test src_var.data == ClimaAnalysis.resampled_as(src_var, src_var).data
    resampled_var = ClimaAnalysis.resampled_as(src_var, dest_var)
    @test resampled_var.data == reshape(1.0:(181 * 91), (181, 91))[1:91, 1:46]
    @test_throws BoundsError ClimaAnalysis.resampled_as(dest_var, src_var)

    # BoundsError check
    src_long = 90.0:120.0 |> collect
    src_lat = 45.0:90.0 |> collect
    src_data = zeros(length(src_long), length(src_lat))
    src_dims = OrderedDict(["long" => src_long, "lat" => src_lat])
    src_var = ClimaAnalysis.OutputVar(
        src_attribs,
        src_dims,
        src_dim_attribs,
        src_data,
    )

    dest_long = 85.0:115.0 |> collect
    dest_lat = 50.0:85.0 |> collect
    dest_data = zeros(length(dest_long), length(dest_lat))
    dest_dims = OrderedDict(["long" => dest_long, "lat" => dest_lat])
    dest_var = ClimaAnalysis.OutputVar(
        dest_attribs,
        dest_dims,
        dest_dim_attribs,
        dest_data,
    )

    @test_throws BoundsError ClimaAnalysis.resampled_as(src_var, dest_var)
end

@testset "Units" begin
    long = -180.0:180.0 |> collect
    data = copy(long)

    # Unitful
    attribs = Dict("long_name" => "hi", "units" => "m/s")
    dim_attributes = OrderedDict(["long" => Dict("units" => "m")])

    var_with_unitful = ClimaAnalysis.OutputVar(
        attribs,
        Dict("long" => long),
        dim_attributes,
        data,
    )
    var_without_unitful = ClimaAnalysis.OutputVar(
        Dict{String, Any}(),
        Dict("long" => long),
        dim_attributes,
        data,
    )

    @test ClimaAnalysis.has_units(var_with_unitful)

    # Convert to cm/s
    var_unitful_in_cms = ClimaAnalysis.convert_units(var_with_unitful, "cm/s")

    @test var_unitful_in_cms.data == 100 .* var_with_unitful.data

    # Unparsable because of new units
    @test_throws ErrorException ClimaAnalysis.convert_units(
        var_with_unitful,
        "bob",
    )

    # New units, using conversion function
    var_notunitful = ClimaAnalysis.convert_units(
        var_with_unitful,
        "bob",
        conversion_function = (data) -> 2 * data,
    )

    @test var_notunitful.data == 2 .* var_with_unitful.data

    # New units parsaeble, but with conversion function
    @test_logs (:warn, "Ignoring conversion_function, units are parseable.") ClimaAnalysis.convert_units(
        var_with_unitful,
        "cm/s",
        conversion_function = (data) -> 2 * data,
    )

end