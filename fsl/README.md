FSL
===

MRI and fMRI analysis using FMRIB Software Library (FSL)

**bet_fsl.sh**    
Brain extraction using **FSL**'s [**bet**](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET) function.   
Allows user to easily redo and view **bet** output several times with various parameters.  
Easy to manually erase excess tissues after automated **bet** (**linux** and **mac**).  

**beta_mean_fsl.sh**  
Extract mean beta (parameter estimate) values using **FSL**'s [**fslmeants**](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Fslutils) function.   
Create files with mean beta values easily from the command line (**linux** and **mac**).  
Can input several options from command line (use **-h** option for directions).  
Must run on higher level **FEAT** folders  

**cluster_grf.sh**  
Run Gaussian Random Field (GRF) statistics using **FSL**'s [**cluster**](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Cluster) function to correct for multiple comparisons.  
Cluster correct several statistic files easily from the command line (**linux** and **mac**).  
Outputs cluster information within **FSL** (g)feat folders (positive and negative values).  
Outputs nifti images that can be easily loaded into other programs (e.g. [**Caret**](http://brainvis.wustl.edu/wiki/index.php/Caret:Download))  
Can input several options from command line (use **-h** option for directions).
