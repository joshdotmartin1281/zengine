# ZEngine
A minimalist 3D engine built with **zig 0.14.1** using openGL's state machine for rendering on the gpu.

## Project Goals
ZEngine is meant to avoid the bloatware that modern engines have with a clear abstraction layer that makes development of new required systems easy.

## Features
* **Acoustic Raytracing:** Sound is done with a raytracing to simulate environmental reflection and spatial reverb.
* **Lighting:** Lighting model that is meant to be lightweight and easy to use different types of lighting.
* **Abstraction:** Seperated modules for window, graphics, input and physics to allow for someone to easily put in their own version to fit their needs.

## Third Party Libraries

GLFW

GLAD

