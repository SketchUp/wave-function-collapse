# Reference Material for Wave Function Collapse

## Interactive Demo
- https://oskarstalberg.com/game/wave/wave.html
- [SGC21- Oskar Stålberg - Beyond Townscapers](https://www.youtube.com/watch?v=Uxeo9c-PX-w)
- [EPC2018 - Oskar Stalberg - Wave Function Collapse in Bad North](https://www.youtube.com/watch?v=0bcZb-SsnrA)

## Entropy
- https://www.boristhebrave.com/2020/04/13/wave-function-collapse-explained/

  > Using the smallest domain works fine if all tiles are equally likely. But if you are choosing the tiles from a weighted random distribution, you need to do something different to take that into account. Maxim recommends “minimal entropy“, which is selecting the cell that minimizes:
  >
  > entropy=−∑pilog(pi)
  >
  > Summing over tiles in the domain, where p_i is the probability associated with that tile.

- https://robertheaton.com/2018/12/17/wavefunction-collapse-algorithm/

  > The entropy formula used in Wavefunction Collapse is Shannon Entropy. It makes use of the tile weights that we parsed from the input image in the previous step:
  >
  >   # Sums are over the weights of each remaining
  >   # allowed tile type for the square whose
  >   # entropy we are calculating.
  >   shannon_entropy_for_square =
  >     log(sum(weight)) -
  >     (sum(weight * log(weight)) / sum(weight))
  >
  > Once we’ve found the square in our wavefunction with the lowest entropy, we collapse its wavefunction. We do this by randomly choosing one of the tiles still available to the square, weighted by the tile weights that we parsed from the example input. We use the weights because they give us a more realistic output image. Suppose that a square’s wavefunction says that it can either be land or coast. We don’t necessarily want to chose each option 50% of the time. If our input image contains more land tiles than coast tiles, we will want to reflect this bias in our output images too. We achieve this by using simple, global weights. If our example image contained 20 land tiles and 10 coast ones, we will collapse our square to land 2/3 of the time and coast the other 1/3.

## Dealing with asymmetry and rotation
- [Superpositions, Sudoku, the Wave Function Collapse algorithm.](https://www.youtube.com/watch?v=2SuvO4Gi7uY)
- https://marian42.de/article/wfc/

## General

- https://chloesun.medium.com/implementation-of-wave-function-collapse-algorithm-in-houdini-for-3d-content-generation-76f8eec573b1
- https://www.gridbugs.org/wave-function-collapse/
