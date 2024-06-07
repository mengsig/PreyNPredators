This is an agent based prey and predator model where each agent has a little brain, represented as a Neural Network. The Neural Network evolves via a genetic algorithm.

There are many parameters to play with, which, will be optimized soon!

Also, please switch between the array and class (modular) approach by going into the "build.zig" file and changing the target from "main.zig" to "mainarray.zig" or vice-versa.

-------------------------------
IMPLEMENTED
-------------------------------
- Cooperation
- Real time population display.
- Array based implementation --> to prepare for GPU implementation.
- Saving of model parameters

-------------------------------
COMING SOON 
-------------------------------
- Better visualization of the agents.
- Display of Neural Nets
- Optimized code for faster runtime.
- CUDA integration?


------------------------------
FUNCTIONAL THINGS
------------------------------
In order to run and build the script, please ensure you have zig installed, and run the following command in your zig environment / directory.

$ zig build run -Dcpu=<your_cpu_architecture_here> -Doptimize=ReleaseFast

Note, that if you do not know your cpu architecture, you can just delete the -flag (I personally use a tigerlake).

![Model](https://github.com/mengsig/PreyNPredators/blob/main/picture.png?raw=true)

Please enjoy, and share!

By: Marcus Engsig & Mikkel Petersen.
