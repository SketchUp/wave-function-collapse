# Wave Function Collapse Experiment

** Warning! ** This is a learning experiment! Don't rely on this project to
be a good example of anything.

This project is based on examples and articles from and derived of https://github.com/mxgmn/WaveFunctionCollapse

Don't refer to this as a good or correct implementation of WFC. Instead check out the [references](References.md).

## The Experiment

The project is a SketchUp extension that takes a set of SketchUp components that acts as tiles in a grid. The bundled example model uses open source assets from [Kenney](https://www.kenney.nl/).

![](pages/images/assets.png)

Note that the extension expects the tiles to be 1x1 meters placed on a `Assets/Tiles` tag.

### Defining Tiles

Before the tiles can be used the edges needs some annotation such that the extension can know which tiles can be placed next to each other. For this a custom tool is used:

![](pages/images/tile-tool.png)

Before an edge can be assigned with a type the available types needs to be defined:

![](pages/images/define-edge-types.gif)

Edge types that are not symmetrical must be annotated as such and they are represented in the UI with an `!` or `¡` symbol. The presence of either symbol indicates that the tile edge is asymmetrical, and the `¡` variant indicate that it's a reversed version of that edge. In order for two asymmetrical edges to be placed next to each other one must be reversed while the other not.

![](pages/images/defined-types.png)

### Generating

Once the tiles are defined the generation can begin:

![](pages/images/generate-default.gif)

The set of tiles used can be narrowed by making a selection before starting the generation:

![](pages/images/generate-selection.gif)

### Weights

As seen in the previous examples, the generated output is filled heavily with roads/rivers. In order to favour a given tile weights can be applied to adjust the distribution of the various tile types:

![](pages/images/generate-weights.gif)
