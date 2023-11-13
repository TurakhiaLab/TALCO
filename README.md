# TALCO
<div align="center">
<!-- <div style="width:400px; height:400px; background-position:center; background-size:cover;"> -->
<!-- </div> -->
<img src="images/talco.gif" style="width:400px; height:400px; margin: 0px 0px -20px 0px;"/>
</div>

**TALCO** is a novel method for **T**iling genome sequence **AL**ignment using
**CO**nvergence of traceback pointers, that, similar to prior tiling techniques, maintains a constant memory footprint during the acceleration step independent of alignment length. However, unlike previous techniques, TALCO also ensures optimal alignments under banding constraints. TALCO does this by leveraging the convergence of traceback paths beyond a tile to a single point on the boundary of that tile – a strategy that seems to generalize well to a broad set of sequence alignment algorithms. To demonstrate generalizability, we apply TALCO to widely-used banded sequence alignment algorithms, X-Drop and WFA-Adapt. We call the modified algorithms
TALCO-XDrop and TALCO-WFAA, respectively.

This repository contains CPU and ASIC implementations of TALCO-XDrop and TALCO-WFAA. We describe TALCO in our paper (**ToDO**).

## **Repository Structure**
```
.
└── 1. dataset
└── 2. hardware # ASIC implementations
	└── TALCO-XDrop
	└── TALCO-WFAA
	└── scripts
└── 3. software # CPU implementations
	└── TALCO-XDrop
	└── TALCO-WFAA
	└── scripts
	└── baselines
```

## **Citing TALCO**

If you use TALCO in your work, please cite the following paper:
(**ToDo**)

## **Getting Help**
We appreciate any feedback and suggestions. Feel free to raise an issue or submit a pull request on GitHub or contact Sumit Walia (swalia AT ucsd DOT edu).
