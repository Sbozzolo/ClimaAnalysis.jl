module ClimaAnalysisGeoMakieExt

import GeoMakie
import GeoMakie: Makie
import ClimaAnalysis
import ClimaAnalysis: Visualize

MakiePlace = Union{Makie.Figure, Makie.GridLayout}

"""
    oceanmask()

Return a collection of polygons to mask out the ocean.

Plot with `Makie.poly`.
"""
function Visualize.oceanmask()
    elevation = 0
    return GeoMakie.NaturalEarth.bathymetry(elevation)
end

"""
    landmask()

Return a collection of polygons to mask out the continents.

Plot with `Makie.poly`.
"""
function Visualize.landmask()
    return GeoMakie.land()
end

function _geomakie_plot_on_globe!(
    place::MakiePlace,
    var::ClimaAnalysis.OutputVar;
    p_loc = (1, 1),
    plot_coastline = true,
    plot_colorbar = true,
    mask = nothing,
    more_kwargs = Dict(
        :plot => Dict(),
        :cb => Dict(),
        :axis => Dict(),
        :coast => Dict(:color => :black),
        :mask => Dict(),
    ),
    plot_fn = Makie.surface!,
)
    length(var.dims) == 2 || error("Can only plot 2D variables")

    lon_name = ""
    lat_name = ""

    for dim in var.index2dim
        if dim in ClimaAnalysis.Var.LONGITUDE_NAMES
            lon_name = dim
        elseif dim in ClimaAnalysis.Var.LATITUDE_NAMES
            lat_name = dim
        else
            error("$dim is neither longitude nor latitude")
        end
    end

    lon = var.dims[lon_name]
    lat = var.dims[lat_name]

    units = ClimaAnalysis.units(var)
    short_name = var.attributes["short_name"]
    colorbar_label = "$short_name [$units]"

    axis_kwargs = get(more_kwargs, :axis, Dict())
    plot_kwargs = get(more_kwargs, :plot, Dict())
    cb_kwargs = get(more_kwargs, :cb, Dict())
    coast_kwargs = get(more_kwargs, :coast, Dict(:color => :black))
    mask_kwargs = get(more_kwargs, :mask, Dict(:color => :white))

    plot_mask = !isnothing(mask)

    var.attributes["long_name"] =
        ClimaAnalysis.Utils.warp_string(var.attributes["long_name"])

    title = get(axis_kwargs, :title, var.attributes["long_name"])

    GeoMakie.GeoAxis(place[p_loc...]; title, axis_kwargs...)

    plot = plot_fn(lon, lat, var.data; plot_kwargs...)
    plot_mask && Makie.poly!(mask; mask_kwargs...)
    plot_coastline && Makie.lines!(GeoMakie.coastlines(); coast_kwargs...)

    if plot_colorbar
        p_loc_cb = Tuple([p_loc[1], p_loc[2] + 1])
        Makie.Colorbar(
            place[p_loc_cb...],
            plot,
            label = colorbar_label;
            cb_kwargs...,
        )
    end
end

"""
    heatmap2D_on_globe!(fig::Makie.Figure,
                        var::ClimaAnalysis.OutputVar;
                        p_loc = (1,1),
                        plot_coastline = true,
                        plot_colorbar = true,
                        mask = nothing,
                        more_kwargs)
    heatmap2D_on_globe!(grid_layout::Makie.GridLayout,
                        var::ClimaAnalysis.OutputVar;
                        p_loc = (1,1),
                        plot_coastline = true,
                        plot_colorbar = true,
                        mask = nothing,
                        more_kwargs)


Plot a heatmap of the given 2D `var`iable on a projected geoid.

The plot comes with labels, units, and a colorbar.

This function assumes that the following attributes are available:
- long_name
- short_name
- units

The dimensions have to be longitude and latitude.

`mask` has to be an object that can be plotted by `Makie.poly`. Typically, an ocean or land
mask. `ClimaAnalysis` comes with predefined masks, check out [`Visualize.oceanmask`](@ref) and
[`Visualize.landmask`](@ref).

!!! note Masking does not affect the colorbar. If you have values defined beneath the map,
    they can still affect the colorbar.

Additional arguments to the plotting and axis functions
=======================================================

`more_kwargs` can be a dictionary that maps symbols to additional options for:
- the axis (`:axis`)
- the plotting function (`:plot`)
- the colorbar (`:cb`)
- the coastline (`:coast`)
- the mask (`:mask`)

The coastline is plotted from `GeoMakie.coastline` using the `lines!` plotting function.

The values are splatted in the relevant functions. Populate them with a
Dictionary of `Symbol`s => values to pass additional options.
"""
function Visualize.heatmap2D_on_globe!(
    place::MakiePlace,
    var::ClimaAnalysis.OutputVar;
    p_loc = (1, 1),
    plot_coastline = true,
    plot_colorbar = true,
    mask = nothing,
    more_kwargs = Dict(
        :plot => Dict(),
        :cb => Dict(),
        :axis => Dict(),
        :coast => Dict(:color => :black),
        :mask => Dict(),
    ),
)
    return _geomakie_plot_on_globe!(
        place,
        var;
        p_loc,
        plot_coastline,
        plot_colorbar,
        mask,
        more_kwargs,
        plot_fn = Makie.surface!,
    )
end

"""
    contours2D_on_globe!(fig::Makie.Figure,
                        var::ClimaAnalysis.OutputVar;
                        p_loc = (1,1),
                        plot_coastline = true,
                        plot_colorbar = true,
                        plot_contours = true,
                        mask = nothing,
                        more_kwargs)
    contours2D_on_globe!(grid_layout::Makie.GridLayout,
                        var::ClimaAnalysis.OutputVar;
                        p_loc = (1,1),
                        plot_coastline = true,
                        plot_colorbar = true,
                        plot_contours = true,
                        mask = nothing,
                        more_kwargs)


Plot discrete contours of the given 2D `var`iable on a projected geoid.

The plot comes with labels, units, and a colorbar.

This function assumes that the following attributes are available:
- long_name
- short_name
- units

The dimensions have to be longitude and latitude.

`mask` has to be an object that can be plotted by `Makie.poly`. Typically, an ocean or land
mask. `ClimaAnalysis` comes with predefined masks, check out [`Visualize.oceanmask`](@ref) and
[`Visualize.landmask`](@ref).

!!! note Masking does not affect the colorbar. If you have values defined beneath the map,
    they can still affect the colorbar.

Additional arguments to the plotting and axis functions
=======================================================

`more_kwargs` can be a dictionary that maps symbols to additional options for:
- the axis (`:axis`)
- the plotting function (`:plot`)
- the colorbar (`:cb`)
- the coastline (`:coast`)
- the mask (`:mask`)

The coastline is plotted from `GeoMakie.coastline` using the `lines!` plotting function.

The values are splatted in the relevant functions. Populate them with a
Dictionary of `Symbol`s => values to pass additional options.
"""
function Visualize.contour2D_on_globe!(
    place::MakiePlace,
    var::ClimaAnalysis.OutputVar;
    p_loc = (1, 1),
    plot_coastline = true,
    plot_colorbar = true,
    mask = nothing,
    more_kwargs = Dict(
        :plot => Dict(),
        :cb => Dict(),
        :axis => Dict(),
        :coast => Dict(:color => :black),
        :mask => Dict(),
    ),
)
    _geomakie_plot_on_globe!(
        place,
        var;
        p_loc,
        plot_coastline,
        plot_colorbar,
        mask,
        more_kwargs,
        plot_fn = Makie.contourf!,
    )
end

"""
    plot_bias_on_globe!(fig::Makie.Figure,
                        sim::ClimaAnalysis.OutputVar,
                        obs::ClimaAnalysis.OutputVar;
                        cmap_extrema = extrema(ClimaAnalysis.bias(sim, obs).data),
                        p_loc = (1, 1),
                        plot_coastline = true,
                        plot_colorbar = true,
                        mask = nothing,
                        more_kwargs)
    plot_bias_on_globe!(grid_layout::Makie.GridLayout,
                        sim::ClimaAnalysis.OutputVar,
                        obs::ClimaAnalysis.OutputVar;
                        cmap_extrema = extrema(ClimaAnalysis.bias(sim, obs).data),
                        p_loc = (1, 1),
                        plot_coastline = true,
                        plot_colorbar = true,
                        mask = nothing,
                        more_kwargs)


Plot the bias (`sim.data - var.data`) on a projected geoid. The gloal bias and root mean
squared error (RMSE) are computed and can be found in the title of the plot. This function
plots the returned `OutputVar` of `ClimaAnalysis.bias(sim, obs)`. See also
[`ClimaAnalysis.bias`](@ref).

The plot comes with labels, units, and a colorbar. This function uses a constrained colormap
based on the values of `cmap_extrema`.

The dimensions have to be longitude and latitude.

`mask` has to be an object that can be plotted by `Makie.poly`. `ClimaAnalysis` comes with
predefined masks, check out [`Visualize.oceanmask`](@ref) and [`Visualize.landmask`](@ref).

!!! note
    Masking does not affect the colorbar. If you have values defined beneath the map, they
    can still affect the colorbar.

Additional arguments to the plotting and axis functions
=======================================================

`more_kwargs` can be a dictionary that maps symbols to additional options for:
- the axis (`:axis`)
- the plotting function (`:plot`)
- the colorbar (`:cb`)
- the coastline (`:coast`)
- the mask (`:mask`)

The coastline is plotted from `GeoMakie.coastline` using the `lines!` plotting function.

The values are splatted in the relevant functions. Populate them with a
Dictionary of `Symbol`s => values to pass additional options.
"""
function Visualize.plot_bias_on_globe!(
    place::MakiePlace,
    sim::ClimaAnalysis.OutputVar,
    obs::ClimaAnalysis.OutputVar;
    cmap_extrema = extrema(ClimaAnalysis.bias(sim, obs).data),
    p_loc = (1, 1),
    plot_coastline = true,
    plot_colorbar = true,
    mask = nothing,
    more_kwargs = Dict(
        :plot => Dict(),
        :cb => Dict(),
        :axis => Dict(),
        :coast => Dict(:color => :black),
        :mask => Dict(),
    ),
)
    bias_var = ClimaAnalysis.bias(sim, obs)
    global_bias = round(bias_var.attributes["global_bias"], sigdigits = 3)
    rmse = round(ClimaAnalysis.global_rmse(sim, obs), sigdigits = 3)
    units = ClimaAnalysis.units(bias_var)

    bias_var.attributes["long_name"] *= " (RMSE: $rmse $units, Global bias: $global_bias $units)"
    min_level, max_level = cmap_extrema

    # Make sure that 0 is at the center
    cmap = Visualize._constrained_cmap(
        Makie.cgrad(:vik).colors,
        min_level,
        max_level;
        categorical = true,
    )
    nlevels = 11
    # Offset so that it covers 0
    levels = collect(range(min_level, max_level, length = nlevels))
    offset = levels[argmin(abs.(levels))]
    levels = levels .- offset
    ticklabels = map(x -> string(round(x; digits = 0)), levels)
    ticks = (levels, ticklabels)

    default_kwargs = Dict(
        :plot => Dict(
            :colormap => cmap,
            :levels => levels,
            :extendhigh => :auto,
            :extendlow => :auto,
        ),
        :cb => Dict(:ticks => ticks),
    )

    # Function for recursively merging two dictionaries if the values of the dictionaries
    # are dictionaries and the values of those are also dictionaries and so on
    # See: https://discourse.julialang.org/t/multi-layer-dict-merge/27261/6
    recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
    recursive_merge(x...) = x[end]
    default_and_more_kwargs = recursive_merge(default_kwargs, more_kwargs)

    return Visualize.contour2D_on_globe!(
        place,
        bias_var;
        p_loc = p_loc,
        plot_coastline = plot_coastline,
        plot_colorbar = plot_colorbar,
        mask = mask,
        more_kwargs = default_and_more_kwargs,
    )
end

end