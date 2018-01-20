[FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
===

MRI and fMRI analysis using FMRIB Software Library ([**FSL**](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki))  
These command line scripts use FSL functions to process several files through automated data analysis steps.

[**bet_fsl.sh**](https://github.com/ealayher/mri/blob/master/fsl/bet_fsl.sh): (**linux** and **mac**)    
Brain extraction using **FSL**'s [**bet**](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET) function.   
Allows user to easily redo and view **bet** output several times with various parameters from command line.  
Easy to manually erase excess tissues after automated **bet**.  
To view all options and script details run **bet_fsl.sh** with (**-h**) option.  

[**beta_mean_fsl.sh**](https://github.com/ealayher/mri/blob/master/fsl/beta_mean_fsl.sh): (**linux** and **mac**)  
Extract mean beta (parameter estimate) values using **FSL**'s [**fslmeants**](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Fslutils) function.   
Create files with mean beta values easily from the command line.  
Must run on higher-level **FEAT** folders.  
To view all options and script details run **beta_mean_fsl.sh** with (**-h**) option.  

[**cluster_grf.sh**](https://github.com/ealayher/mri/blob/master/fsl/cluster_grf.sh): (**linux** and **mac**)  
Run Gaussian Random Field (GRF) statistics using **FSL**'s [**cluster**](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Cluster) function to correct for multiple comparisons.  
Cluster correct several statistic files easily from the command line.  
Outputs cluster information within **FSL** (**G**)**FEAT** directories (positive and negative values).  
Outputs nifti images that can be easily loaded into other programs (e.g. [**Caret5**](http://brainvis.wustl.edu/wiki/index.php/Caret:Download)).    
To view all options and script details run **cluster_grf.sh** with (**-h**) option. 

[**motion_qc_fsl.sh**](https://github.com/ealayher/mri/blob/master/fsl/motion_qc_fsl.sh): (**linux** and **mac**)  
Obtain lower-level **FEAT** motion (absolute and relative) and quality control parameters from the command line.  
Calculates full width at half maximum (FWHM) and signal-to-fluctuation noise ratios (SFNR).  
SFNR requires: [**avg152T1_gray_Pmap.nii.gz**](https://github.com/ealayher/mri/blob/master/fsl/avg152T1_gray_Pmap.nii.gz)  
Outputs quality control information into single CSV file.  
To view all options and script details run **motion_qc_fsl.sh** with (**-h**) option. 

[**percent_signal_change_fsl.sh**](https://github.com/ealayher/mri/blob/master/fsl/percent_signal_change_fsl.sh): (**linux** and **mac**)  
Creates percent signal change NIFTI files from full analysis **FEAT** directories.  
To view all options and script details run **percent_signal_change_fsl.sh** with (**-h**) option. 
