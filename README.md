mri
==========

Magnetic resonance imaging (MRI) data analyses: functional (fMRI) and structural MRI

[**rename_dcm_files.sh**](https://github.com/ealayher/mri/blob/master/rename_dcm_files.sh): (**linux** and **mac**)  
Rename DICOM files into organized data structure.  
To view all options and script details run **rename_dcm_files.sh** with (**-h**) option.

Requires [**DICOM Toolkit**](http://dicom.offis.de/dcmtk.php.en):  
(1) Download source code (e.g. *dcmtk-3.6.2.tar.gz*)  
(2) cd into main directory  
(3) Run commands:  
&nbsp;&nbsp;&nbsp;&nbsp;[1] **./configure**  
&nbsp;&nbsp;&nbsp;&nbsp;[2] **make all**  
&nbsp;&nbsp;&nbsp;&nbsp;[3] **make install** (mac), **sudo make install** (linux)  
&nbsp;&nbsp;&nbsp;&nbsp;[4] **make distclean**
