This is an agent based prey and predator model where each agent has a little brain, represented as a Neural Network. The Neural Network evolves via a genetic algorithm.

There are many parameters to play with, which, will be optimized soon!

Also, please switch between the array and class (modular) approach by going into the "build.zig" file and changing the target from "main.zig" to "mainarray.zig" or vice-versa.

-------------------------------
IMPLEMENTED
-------------------------------
- Cooperation
- Real time population display.
- Array based implementation --> to prepare for GPU implementation.
- Saving of neural networks.

-------------------------------
COMING SOON 
-------------------------------
- Better visualization of the agents.
- Display of Neural Nets
- Optimized code for faster runtime.
- CUDA integration?
- Loading of neural networks.


------------------------------
FUNCTIONAL THINGS
------------------------------
-----------------------
How to use!
-----------------------
Please download Zig! It is a great language after all!

If you have a debian distribution, install Zig via the following command:

$ sudo snap install zig

If you do not have the snap package manager, you can install it via:

$ sudo apt-get update

$ sudo apt-get install snapd

And then of course running the command to install zig.

$ sudo snap install zig


If you have a MacOS, you can install Zig via Brew with the following command:

$ brew install zig

Otherwise, you have to do a manual installation of Zig (see https://github.com/ziglang/zig).


In order to run and build the script, please ensure you have zig installed, and run the following command in your zig environment / directory.

$ zig build run -Doptimize=ReleaseFast 

![Model](https://github.com/mengsig/PreyNPredators/blob/main/picture.png?raw=true)

Please enjoy, and share!

By: Marcus Engsig & Mikkel Petersen.
