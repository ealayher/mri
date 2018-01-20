#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 11/28/2015 By: Nikki Marinsek (1.0)
# Revised: 01/04/2017 By: Evan Layher (layher@psych.ucsb.edu) (2.0): Mac and linux compatible
# Revised: 01/13/2018 By: Evan Layher (2.1): Specify all parameters from command line
#--------------------------------------------------------------------------------------#
# Create CARET5 fMRI images from command line
# Requires CARET (http://brainvis.wustl.edu/wiki/index.php/Caret:Download)
# Requires CARET_TUTORIAL_SEPT06 (http://brainvis.wustl.edu/sumsdb/zip_targz_tgz/6595030_CARET_TUTORIAL_SEPT06.zip)
# Requires ImageMagick (https://www.imagemagick.org/script/download.php)

## --- LICENSE INFORMATION --- ##
## Modified BSD-2 License - for Non-Commercial Use Only

## Copyright (c) 2017-18, The Regents of the University of California
## All rights reserved.

## Redistribution and use in source and binary forms, with or without modification, are 
## permitted for non-commercial use only provided that the following conditions are met:

## 1. Redistributions of source code must retain the above copyright notice, this list 
##    of conditions and the following disclaimer.

## 2. Redistributions in binary form must reproduce the above copyright notice, this list 
##    of conditions and the following disclaimer in the documentation and/or other 
##    materials provided with the distribution.

## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
## EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
## OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
## SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
## INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
## TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; 
## OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY 
## WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## For permission to use for commercial purposes, please contact UCSB’s Office of 
## Technology & Industry Alliances at 805-893-5180 or info@tia.ucsb.edu.
## --------------------------- ##

#-------------------------------- VARIABLES --------------------------------#
caret_dirs=('/Applications/carets') # Main CARET folder(s) (Finds folder if these are missing)
def_caret_data_dir='data_files/fmri_mapping_files' # Default CARET data folder within 'caret' folder
def_caret_map_dir='CARET_TUTORIAL_SEPT06/MAPPING_PROCEDURES' # Default CARET mapping files within "${def_caret_data_dir}"

verify_time='10' # (secs) Display settings before running (input -s to suppress)
def_dims=('192' '192') # (default) raw image pixel dimensions (see image crop factors below)

#---- CARET display maps within "${caret_map_dir}" (final image coordinate file surfaces) ----#
fiducial_disp_left_coord_file='Human.PALS_B12.LEFT_AVG_B1-12.FIDUCIAL_FLIRT.clean.73730.coord'
fiducial_disp_right_coord_file='Human.PALS_B12.RIGHT_AVG_B1-12.FIDUCIAL_FLIRT.clean.73730.coord'
flat_disp_left_coord_file='Human.PALS_B12.LEFT.FLAT.CartSTD.73730.coord'
flat_disp_right_coord_file='Human.PALS_B12.RIGHT.FLAT.CartSTD.73730.coord'
inflated_disp_left_coord_file='Human.PALS_B12.LEFT_AVG_B1-12.INFLATED.clean.73730.coord'
inflated_disp_right_coord_file='Human.PALS_B12.RIGHT_AVG_B1-12.INFLATED.clean.73730.coord'
very_inflated_disp_left_coord_file='Human.PALS_B12.LEFT_AVG_B1-12.VERY_INFLATED.clean.73730.coord'
very_inflated_disp_right_coord_file='Human.PALS_B12.RIGHT_AVG_B1-12.VERY_INFLATED.clean.73730.coord'

#---- CARET default mapping files to create metric (FSL: FLIRT) ----#
def_mapping_left_coord_file="${fiducial_disp_left_coord_file}"   # Left fiducial (map files, but not display)
def_mapping_right_coord_file="${fiducial_disp_right_coord_file}" # Right fiducial (map files, but not display)
def_left_topo_file='Human.sphere_6.LEFT_HEM.73730.topo'   # ${caret_data_dir}
def_right_topo_file='Human.sphere_6.RIGHT_HEM.73730.topo' # ${caret_data_dir}
def_spec_file='Human.PALS_B12.BOTH.TEMPLATE-for-fMRI-MAPPING.73730.spec'
def_scene='PALS_BOTH_TEMPLATE-for-MAPPING.scene'

#---- CARET display brain type (-b) (coordinate files) ----#
b1='fiducial'      # Brain type 1 (fiducial)
b2='flat'          # Brain type 2 (flat)
b3='inflated'      # Brain type 3 (inflated)
b4='very-inflated' # Brain type 4 (very inflated)
val_coords=("${b1}" "${b2}" "${b3}" "${b4}") # Valid '.coord' files
def_coord="${b3}" # Default '.coord' file (inflated)
# Coordinate files that correspond with 'val_coords'
left_coords=("${fiducial_disp_left_coord_file}" "${flat_disp_left_coord_file}" "${inflated_disp_left_coord_file}" "${very_inflated_disp_left_coord_file}")
right_coords=("${fiducial_disp_right_coord_file}" "${flat_disp_right_coord_file}" "${inflated_disp_right_coord_file}" "${very_inflated_disp_right_coord_file}")

#---- CARET algorithms to map volumes to surfaces (-a) ----#
a1='METRIC_AVERAGE_NODES'      # CARET input word: (metric average nodes)
a2='METRIC_AVERAGE_VOXEL'      # CARET input word: (metric average voxel)
a3='METRIC_ENCLOSING_VOXEL'    # CARET input word: (metric enclosing voxel)
a4='METRIC_GAUSSIAN'           # CARET input word: (metric gaussian)
a5='METRIC_INTERPOLATED_VOXEL' # CARET input word: (metric interpolated voxel)
a6='METRIC_MAXIMUM_VOXEL'      # CARET input word: (metric maximum voxel)
a7='METRIC_MCW_BRAIN_FISH'     # CARET input word: (metric MCW brain fish)
a8='METRIC_STRONGEST_VOXEL'    # CARET input word: (metric strongest voxel)
a9='PAINT_ENCLOSING_VOXEL'     # CARET input word: (metric enclosing voxel)
val_algos=("${a1}" "${a2}" "${a3}" "${a4}" "${a5}" "${a6}" "${a7}" "${a8}" "${a9}") # valid algorithms
def_algo="${a5}" # default algorithm (metric interpolated voxel)

#---- Image crop factors (6 inputs from: 0 - 1) (-c = crop, -cn = NO crop)----#
# (1) x-dimension (percentage of raw image to keep)
# (2) y-dimension (percentage of raw image to keep)
# (3) x-dimension shift left hemisphere (percentage of raw image from right to start crop)
# (4) y-dimension shift left hemisphere (percentage of raw image from top to start crop)
# (5) x-dimension shift right hemisphere (percentage of raw image from right to start crop)
# (6) y-dimension shift right hemisphere (percentage of raw image from top to start crop)
tot_crop_vals='6' # total number of crop values expected
def_b1_crop_ap=('0.307' '0.563' '0.490' '0.156' '0.203' '0.156') # fiducial
def_b1_crop_dv=('0.302' '0.760' '0.208' '0.198' '0.495' '0.198') # fiducial
def_b1_crop_lm=('0.776' '0.557' '0.182' '0.151' '0.042' '0.151') # fiducial
def_b2_crop_dv=('0.922' '0.719' '0.078' '0.125' '0.011' '0.125') # flat (only shows in dorsal/ventral views)
def_b3b4_crop_ap=('0.375' '0.615' '0.318' '0.193' '0.307' '0.193') # inflated/very inflated
def_b3b4_crop_dv=('0.385' '0.875' '0.308' '0.047' '0.308' '0.047') # inflated/very inflated
def_b3b4_crop_lm=('0.917' '0.651' '0.031' '0.188' '0.057' '0.188') # inflated/very inflated

#---- Composite output image configuration (-cc = create, -ccn = do NOT create) ----#
left_ant_code='la'  # configuration code (left anterior)
left_dor_code='ld'  # configuration code (left dorsal)
left_lat_code='ll'  # configuration code (left lateral)
left_med_code='lm'  # configuration code (left medial)
left_pos_code='lp'  # configuration code (left posterior)
left_ven_code='lv'  # configuration code (left ventral)
right_ant_code='ra' # configuration code (right anterior)
right_dor_code='rd' # configuration code (right dorsal)
right_lat_code='rl' # configuration code (right lateral)
right_med_code='rm' # configuration code (right medial)
right_pos_code='rp' # configuration code (right posterior)
right_ven_code='rv' # configuration code (right ventral)

# CARET viewpoints keywords
caret_ant='ANTERIOR'
caret_dor='DORSAL'
caret_lat='LATERAL'
caret_med='MEDIAL'
caret_pos='POSTERIOR'
caret_ven='VENTRAL'

val_comp_codes=("${left_ant_code}" "${left_dor_code}" "${left_lat_code}" "${left_med_code}" \
	"${left_pos_code}" "${left_ven_code}" "${right_ant_code}" "${right_dor_code}" \
	"${right_lat_code}" "${right_med_code}" "${right_pos_code}" "${right_ven_code}") # Valid codes

def_comp_dims=('2' '2') # Default composite image configuration (rows x cols)
def_comp_order=("${left_lat_code}" "${right_lat_code}" "${left_med_code}" "${right_med_code}") # Reads rows left to right
def_comp_order_b2=("${left_dor_code}" "${right_dor_code}" "${left_ven_code}" "${right_ven_code}") # Flat brain only visible in dorsal/ventral
#---- Label options (-l) (imageMagick) ----X
def_text_size='12'
val_text_colors=('black' 'blue' 'gold' 'green' 'none' 'pink' 'purple' 'red' 'white' 'yellow') # ImageMagick color options
def_text_color='white'
def_bg_color='none'
val_label_pos=('center' 'east' 'north' 'northeast' 'northwest' 'south' 'southeast' 'southwest' 'west')
def_label_pos='center'
#---- Label options (-l) (CARET) 5 inputs: X/Y pixel location, 3 RGB color codes ----X
def_caret_label_options=('0' '0' '255' '255' '255') # bottom left corner/white

#---- Filename endings ----#
l_ant='_l_ant' # Left anterior files
l_dor='_l_dor' # Left dorsal files
l_lat='_l_lat' # Left lateral files
l_med='_l_med' # Left medial files
l_pos='_l_pos' # Left posterior files
l_ven='_l_ven' # Left ventral files
r_ant='_r_ant' # Right anterior files
r_dor='_r_dor' # Right dorsal files
r_lat='_r_lat' # Right lateral files
r_med='_r_med' # Right medial files
r_pos='_r_pos' # Right posterior files
r_ven='_r_ven' # Right ventral files
left='_left'   # Left files
right='_right' # Right files
coord_ext='.coord'   # CARET coordinate file extension
image_ext='.jpg'     # Final image output extension
metric_ext='.metric' # CARET metric file extension
scene_ext='.scene'   # CARET scene file extension
spec_ext='.spec'     # CARET specification file extension
topo_ext='.topo'     # CARET topology file extension
volume_exts=('.HEAD' '.hdr' '.ifh' '.nii' '.nii.gz') # Valid input volume extensions

rm_all_keyword='all' # Used with -f/-rm to force overwrite or remove all excess output files

#---- Software links ----#
caret_link='http://brainvis.wustl.edu/wiki/index.php/Caret:Download'
caret_tutorial_link='http://brainvis.wustl.edu/sumsdb/zip_targz_tgz/6595030_CARET_TUTORIAL_SEPT06.zip'
image_magick_link='https://www.imagemagick.org/script/download.php'

# awk_product: parameters
decimal_places='4' # Maximum number of decimals in output
max_chars='95'     # 'awk' error when input >100 characters (uses loop if character count > ${max_chars})
nums_per_loop='20' # Default number of inputs per loop
#--------------------------- DEFAULT SETTINGS ------------------------------#
text_editors=('kwrite' 'kate' 'gedit' 'open -a /Applications/BBEdit.app' 'open') # GUI text editor commands in preference order

IFS_old="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (useful when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
usage () { # Help message: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: Create ${gre}CARET${whi} '${ora}${image_ext}${whi}' images
Quickly create ${gre}CARET${whi} images of an input volume from various viewpoints
Output images have orange/yellow ${ora}(${gre}+${ora})${whi} and light-blue/blue ${ora}(${red}-${ora})${whi} color coding
Create composite image with multiple viewpoints and labels

${ora}REQUIREMENTS${whi}:
${gre}CARET${whi}: ${pur}${caret_link}${whi}
${gre}CARET_TUTORIAL_SEPT06${whi}: ${pur}${caret_tutorial_link}${whi}
${gre}ImageMagick${whi}: ${pur}${image_magick_link}${whi}
     
${ora}ADVICE${whi}: Create an alias inside your ${ora}${HOME}/.bashrc${whi} file
${ora}(${whi}e.g. ${gre}alias caret='${script_path}'${ora})${whi}
     
${ora}USAGE${whi}: Specify input volume and output '${ora}${image_ext}${whi}' image
 [${ora}1${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1${whi}
 # Creates composite image: ${ora}~/z1${image_ext}${whi}
 # Creates individual images: ${pur}(${whi}e.g. ${ora}~/z1${l_lat}${image_ext}${pur})${whi}
 # Creates ${gre}CARET ${whi}files: '${ora}${metric_ext}${whi}', '${ora}${spec_ext}${whi}', '${ora}${scene_ext}${whi}'
     
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-a${whi}   Specify algorithm for mapping metric file ${ora}(${pur}INPUT TYPES BELOW${ora})${whi}
 ${pur}-b${whi}   Specify display brain coordinate file ${ora}(${pur}INPUT TYPES BELOW${ora})${whi}
 ${pur}-c${whi}   Crop images with 6 inputs ${ora}(${pur}REQUIRES: ${gre}ImageMagick${ora})${whi}
      ${ora}(${pur}1${ora})${whi} crop X-dimension to percentage of original image size ${ora}(${pur}0${whi} - ${pur}1${ora})${whi}
      ${ora}(${pur}2${ora})${whi} crop Y-dimension to percentage of original image size ${ora}(${pur}0${whi} - ${pur}1${ora})${whi}
      ${ora}(${pur}3${ora})${whi} shift X-dimension of left hemisphere from right side ${ora}(${pur}0${whi} - ${pur}1${ora})${whi}
      ${ora}(${pur}4${ora})${whi} shift Y-dimension of left hemisphere from top side ${ora}(${pur}0${whi} - ${pur}1${ora})${whi}
      ${ora}(${pur}5${ora})${whi} shift X-dimension of right hemisphere from right side ${ora}(${pur}0${whi} - ${pur}1${ora})${whi}
      ${ora}(${pur}6${ora})${whi} shift Y-dimension of right hemisphere from top side ${ora}(${pur}0${whi} - ${pur}1${ora})${whi}
 [${ora}2${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-c${whi} # Default settings
 [${ora}3${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-c ${ora}$(printf '%s ' ${def_b1_crop_lm[@]})${whi}
 ${pur}-cc${whi}  Create composite image
      ${ora}(${pur}1${ora})${whi} 2 composite image dimensions ${ora}(${whi}integers > 0${ora})${whi}
      ${ora}(${pur}2${ora})${whi} Configuration codes in left to right order ${ora}(${pur}INPUT TYPES BELOW${ora})${whi}
 [${ora}4${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-cc${whi} # Default settings
 [${ora}5${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-cc ${ora}$(printf '%s ' ${def_comp_dims[@]})${whi}
 [${ora}6${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-cc ${ora}$(printf '%s ' ${def_comp_order[@]})${whi}
 [${ora}7${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-cc ${ora}$(printf '%s ' ${def_comp_dims[@]})$(printf '%s ' ${def_comp_order[@]})${whi}
 ${pur}-ccn${whi} Do ${red}NOT ${whi}create composite image ${ora}(${whi}input configuration codes${ora})${whi}
 [${ora}8${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-ccn ${ora}$(printf '%s ' ${def_comp_order[@]})${whi}
 ${pur}-cn${whi}  Do ${red}NOT ${whi}crop images
 ${pur}-co${whi}  Execute ${gre}CARET ${whi}commands only ${ora}(${red}NOT ${gre}ImageMagick${ora}) ${red}unable to crop images${whi}
 ${pur}-cs${whi}  Prevent screen from clearing before script processes
 ${pur}-d${whi}   Output image pixel dimensions before cropping ${ora}(${whi}integers > 0${ora})${whi}
 [${ora}9${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-d ${ora}$(printf '%s ' ${def_dims[@]})${whi}
 ${pur}-f${whi}   Force overwrite old images ${ora}(${whi}use keyword ${pur}${rm_all_keyword} ${whi}to overwrite ${gre}CARET ${whi}files${ora})${whi}
 [${ora}10${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-f${whi} # Overwrite old images only
 [${ora}11${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-f all${whi} # Overwrite ${gre}CARET ${whi}files too
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-l${whi}   Label image(s): Composite first, then image labels ${ora}(${pur}INPUT TYPES BELOW${ora})${whi}
 [${ora}12${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-l ${ora}'Sub1'${whi} # Composite label
 [${ora}13${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-l ${ora}'Sub1' 12${whi} # 12-point font
 [${ora}14${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-cc ${ora}${left_lat_code} ${right_lat_code} ${left_med_code} ${right_med_code} ${pur}-l ${ora}'Sub1' 'Left lateral' 'Right lateral' 'Left Medial' 'Right Medial'${whi} # Composite label, then image labels
 [${ora}15${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-cc ${ora}${left_lat_code} ${pur}-l ${ora}'Sub1' 12 8${whi} # 12-point composite label, 8-point image label
 [${ora}16${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-l ${ora}'Sub1' ${def_text_color} ${def_bg_color}${whi} # Color: text, background
 [${ora}17${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-l ${ora}'Sub1' ${def_label_pos}${whi} # Label position
 [${ora}18${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-l ${pur}-l ${ora}12 8${whi} # Input extra ${pur}-l ${whi}before number, color, or position to use as label. Label=12, font-size=8
 [${ora}19${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-l ${ora}12 ${pur}-l ${ora}8${whi} # Label=8, font-size=12
 [${ora}20${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-co ${pur}-l ${ora}0 0 255 255 255${whi} # ${gre}CARET ${whi}command, 5 inputs: x/y pixel position from bottom left corner, 3 RGB values ${ora}(${whi}0-255${ora})${whi}
 ${pur}-left${whi} Specify ${gre}CARET ${whi}input files ${ora}(${whi}Left hemisphere ${ora}OR ${whi}whole brain files${ora})${whi}
 ${ora}NOTE: ${whi}Input ${ora}${coord_ext} ${whi}files: mapping then display ${ora}(${whi}only input 1 file for both${ora})${whi}
 [${ora}21${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-left ${ora}~/${fiducial_disp_left_coord_file} ~/${def_scene} ~/${def_spec_file} ~/${def_left_topo_file}${whi}
 ${pur}-mkdir${whi} Create specified output folder
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-right${whi} Specify ${gre}CARET ${whi}input files ${ora}(${whi}Right hemisphere ${ora}OR ${whi}whole brain files${ora})${whi}
 ${ora}NOTE: ${whi}Input ${ora}${coord_ext} ${whi}files: mapping then display ${ora}(${whi}only input 1 file for both${ora})${whi}
 [${ora}22${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-right ${ora}~/${fiducial_disp_right_coord_file} ~/${inflated_disp_right_coord_file}${whi}
 ${pur}-rm${whi}  Remove output ${gre}CARET ${whi}files ${ora}(${whi}use keyword ${pur}${rm_all_keyword} ${whi}to remove non-composite images${ora})${whi}
 [${ora}23${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-rm${whi} # Remove output ${gre}CARET${whi} files
 [${ora}24${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-f all${whi} # Remove individual output images too
 ${pur}-s${whi}   Suppress startup message and run script immediately
 ${pur}-t${whi}   Threshold image with minimum and maximum value
 ${ora}NOTE: ${whi}Thesholds in both positive and negative directions
 [${ora}25${whi}] ${gre}caret ${ora}~/zstat1.nii.gz ~/z1 ${pur}-t ${ora}2.3 6.0${whi} # thresholds 2.3 - 6 ${red}AND ${whi}-2.3 - -6
 ${pur}-v${whi}   View output composite image once created
 
${ora}INPUT TYPES${whi}:
${pur}Input volume extensions${whi}:
$(display_values ${volume_exts[@]})
${pur}Output filename add-ons for individual images and ${gre}CARET ${pur}files${whi}:
Left anterior  : ${ora}${l_ant}${image_ext}${whi}, ${ora}${l_ant}${metric_ext}${whi}, ${ora}${l_ant}${scene_ext}${whi}
Left dorsal    : ${ora}${l_dor}${image_ext}${whi}, ${ora}${l_dor}${metric_ext}${whi}, ${ora}${l_dor}${scene_ext}${whi}
Left lateral   : ${ora}${l_lat}${image_ext}${whi}, ${ora}${l_lat}${metric_ext}${whi}, ${ora}${l_lat}${scene_ext}${whi}
Left medial    : ${ora}${l_med}${image_ext}${whi}, ${ora}${l_med}${metric_ext}${whi}, ${ora}${l_med}${scene_ext}${whi}
Left posterior : ${ora}${l_pos}${image_ext}${whi}, ${ora}${l_pos}${metric_ext}${whi}, ${ora}${l_pos}${scene_ext}${whi}
Left ventral   : ${ora}${l_ven}${image_ext}${whi}, ${ora}${l_ven}${metric_ext}${whi}, ${ora}${l_ven}${scene_ext}${whi}
Right anterior : ${ora}${r_ant}${image_ext}${whi}, ${ora}${r_ant}${metric_ext}${whi}, ${ora}${r_ant}${scene_ext}${whi}
Right dorsal   : ${ora}${r_dor}${image_ext}${whi}, ${ora}${r_dor}${metric_ext}${whi}, ${ora}${r_dor}${scene_ext}${whi}
Right lateral  : ${ora}${r_lat}${image_ext}${whi}, ${ora}${r_lat}${metric_ext}${whi}, ${ora}${r_lat}${scene_ext}${whi}
Right medial   : ${ora}${r_med}${image_ext}${whi}, ${ora}${r_med}${metric_ext}${whi}, ${ora}${r_med}${scene_ext}${whi}
Right posterior: ${ora}${r_pos}${image_ext}${whi}, ${ora}${r_pos}${metric_ext}${whi}, ${ora}${r_pos}${scene_ext}${whi}
Right ventral  : ${ora}${r_ven}${image_ext}${whi}, ${ora}${r_ven}${metric_ext}${whi}, ${ora}${r_ven}${scene_ext}${whi}

${ora}(${pur}-a${ora}) ${pur}Algorithms for metric file mapping${whi}:
$(display_values ${val_algos[@]})
${ora}(${pur}-b${whi}${ora}) ${pur}Brain output coordinate files${whi}:
$(display_values ${val_coords[@]})
${ora}(${pur}-cc${whi}/${pur}-ccn${ora}) ${pur}Configuration codes for output image viewpoints${whi}:
Left anterior  : ${ora}${left_ant_code}${whi}
Left dorsal    : ${ora}${left_dor_code}${whi}
Left lateral   : ${ora}${left_lat_code}${whi}
Left medial    : ${ora}${left_med_code}${whi}
Left posterior : ${ora}${left_pos_code}${whi}
Left ventral   : ${ora}${left_ven_code}${whi}
Right anterior : ${ora}${right_ant_code}${whi}
Right dorsal   : ${ora}${right_dor_code}${whi}
Right lateral  : ${ora}${right_lat_code}${whi}
Right medial   : ${ora}${right_med_code}${whi}
Right posterior: ${ora}${right_pos_code}${whi}
Right ventral  : ${ora}${right_ant_code}${whi}

${ora}(${pur}-l${ora}) ${pur}Label text positions ${gre}ImageMagick${whi}:
${ora}NOTE: ${pur}-co ${whi}: use 2 integer values for bottom-left pixel position
$(display_values ${val_label_pos[@]})
${ora}(${pur}-l${ora}) ${pur}Label text and background colors with ${gre}ImageMagick${whi}:
${ora}NOTE: ${pur}-co ${whi}: use 3 RGB codes ${ora}(${whi}0-255${ora})${whi} for text color ${ora}(${red}no background color${ora})${whi}
$(display_values ${val_text_colors[@]})
${ora}DEFAULT SETTINGS${whi}:
${ora}(${pur}-a${ora})${whi} algorithm: ${gre}${def_algo}${whi} # metric file mapping
${ora}(${pur}-b${ora})${whi} output brain: ${gre}${def_coord}${whi} # coordinate file
${ora}(${pur}-c${ora})${whi} crop images: ${gre}${crop_imgs}${whi} # Crop out excessive black background
${ora}(${pur}-cc${ora})${whi} create composite: ${gre}${create_comp}${whi}, dimensions: ${ora}${def_comp_dims[0]}${whi}x${ora}${def_comp_dims[1]}${whi}, order: ${ora}$(printf '%s ' ${def_comp_order[@]})${whi}
${ora}(${pur}-d${ora})${whi} output image dimensions: ${ora}${def_dims[0]}${whi}x${ora}${def_dims[1]}${whi} # pixels
${ora}(${pur}-l${ora})${whi} Label text size/position/color, background color: ${ora}${def_text_size}${whi}/${ora}${def_label_pos}${whi}/${ora}${def_text_color}${whi}, ${ora}${def_bg_color}
     
${ora}VERSION: ${gre}${version}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm -nt
} # usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
start_time=$(date +%s) # Time in seconds
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version='2.1' # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
caret_only='no'       # 'no' : Only use caret commands   [INPUT: '-co']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
create_comp='yes'     # 'yes': Create composite image    [INPUT: '-cc', '-ccn' (no composition)]
create_dir='no'       # 'no' : Create folder             [INPUT: '-mkdir']
crop_imgs='yes'       # 'yes': Crop raw images           [INPUT: '-c', '-cn' (no crop)]
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
force_ow_imgs='no'    # 'no' : Overwrite old images      [INPUT: '-f']
force_ow_misc='no'    # 'no' : Overwrite CARET files     [INPUT: '-f'; ${rm_all_keyword}]
include_label='no'    # 'no' : Add final image label     [INPUT: '-l']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
read_literal='no'     # 'no' : Label read literal        [INPUT: '-l'; '-l'] (input before value)
rm_imgs='no'          # 'no' : Remove output images      [INPUT: '-rm'; ${rm_all_keyword}]
rm_misc='no'          # 'no' : Remove output CARET files [INPUT: '-rm']
show_time='yes'       # 'yes': Display process time      [INPUT: '-nt']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')
suppress_msg='no'     # 'no' : Do NOT verify parameters  [INPUT: '-s']
thresh='no'           # 'no' : Threshold volume          [INPUT: '-t']
view_image='no'       # 'no' : Open composite image      [INPUT: '-v'] 

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate user inputs
	if [ "${1}" == '-a' 2>/dev/null ] || [ "${1}" == '-b' 2>/dev/null ] || \
	   [ "${1}" == '-c' 2>/dev/null ] || [ "${1}" == '-cc' 2>/dev/null ] || \
	   [ "${1}" == '-ccn' 2>/dev/null ] || [ "${1}" == '-cn' 2>/dev/null ] || \
	   [ "${1}" == '-co' 2>/dev/null ] || [ "${1}" == '-cs' 2>/dev/null ] || \
	   [ "${1}" == '-d' 2>/dev/null ] || [ "${1}" == '-f' 2>/dev/null ] || \
	   [ "${1}" == '-h' 2>/dev/null ] || [ "${1}" == '--help' 2>/dev/null ] || \
	   [ "${1}" == '-l' 2>/dev/null ] || [ "${1}" == '-left' 2>/dev/null ] || \
	   [ "${1}" == '-mkdir' 2>/dev/null ] || [ "${1}" == '-nc' 2>/dev/null ] || \
	   [ "${1}" == '-nm' 2>/dev/null ] || [ "${1}" == '-nt' 2>/dev/null ] || \
	   [ "${1}" == '-o' 2>/dev/null ] || [ "${1}" == '--open' 2>/dev/null ] || \
	   [ "${1}" == '-right' 2>/dev/null ] || [ "${1}" == '-rm' 2>/dev/null ] || \
	   [ "${1}" == '-s' 2>/dev/null ] || [ "${1}" == '-t' 2>/dev/null ] || \
	   [ "${1}" == '-v' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ "${a_in}" == 'yes' 2>/dev/null ]; then # -a (CARET mapping algorithm)
		algo="${1}"
		# Check for valid algorithm input
		chk_algo=($(printf "%s${IFS}" ${val_algos[@]} |grep "^${algo}$"))
		if [ "${#chk_algo[@]}" -eq '0' ]; then # Invalid input
			bad_inputs+=("INVALID-ALGORITHM_-a:${algo}")
		fi
		
		a_in='no' # Only get 1 value
	elif [ "${b_in}" == 'yes' 2>/dev/null ]; then # -b (CARET brain map)
		disp_coord="${1}"
		# Check value
		chk_disp=($(printf "%s${IFS}" ${val_coords[@]} |grep "^${disp_coord}$"))
		if [ "${#chk_disp[@]}" -eq '0' ]; then # Invalid input
			bad_inputs+=("INVALID-CARET-MAP_-b:${disp_coord}")
		fi
		
		b_in='no' # Only get 1 value
	elif [ "${c_in}" == 'yes' 2>/dev/null ]; then # -c (Crop images with ImageMagick)
		chk_c=$(echo "${1}" |awk '{print ($1 >= 0 && $1 <= 1)}') # 1 = valid, 0 = invalid
		if [ "${chk_c}" -eq '1' ]; then # Decimal from 0 - 1
			crop_dims+=("${1}")
		else # Invalid input
			bad_inputs+=("CROP-VALUE-MUST-BE-FROM-0-TO-1_-c:${1}")
		fi
	elif [ "${cc_in}" == 'yes' 2>/dev/null ]; then # -cc (Create composite image with ImageMagick)
		if [ "${1}" -ge '1' 2>/dev/null ]; then # Composite configuration
			comp_dims+=("${1}")
		else # Check configuration code (left/right, anterior/dorsal/lateral/medial/posterior/ventral)
			chk_comp_vals=($(printf "%s${IFS}" ${val_comp_codes[@]} |grep "^${1}$"))
			if [ "${#chk_comp_vals[@]}" -eq '0' ]; then
				bad_inputs+=("COMPSITE-INPUT-MUST-BE-INTEGER-OR-DIRECTION-CODE_-cc:${1}")
			else # Record configuration order
				comp_order+=("${1}")
			fi
		fi # if [ "${1}" -ge "1" 2>/dev/null ]
	elif [ "${d_in}" == 'yes' 2>/dev/null ]; then # -d (Image dimensions before cropping)
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -ge '0' 2>/dev/null ]; then
			dims+=("${1}") # Raw image dimensions
		else # Invalid input (integer > 0)
			bad_inputs+=("DIMENSION-VALUE-MUST-BE-WHOLE-NUMBER_-d:${1}")
		fi
	elif [ "${f_in}" == 'yes' 2>/dev/null ]; then # -f (Force overwrite old files)
		if [ "${1}" == "${rm_all_keyword}" 2>/dev/null ]; then
			force_ow_misc='yes' # Overwrite old CARET files (in addition to old images)
		else # Invalid input (${rm_all_keyword})
			bad_inputs+=("INVALID-INPUT:USE-${rm_all_keyword}_-f:${1}")
		fi
	elif [ "${l_in}" == 'yes' 2>/dev/null ]; then # -l (Record output label)
		chk_color_txt=($(printf "%s${IFS}" ${val_text_colors[@]} |grep "^${1}$"))
		chk_label_pos=($(printf "%s${IFS}" ${val_label_pos[@]} |grep "^${1}$"))
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${read_literal}" == 'no' 2>/dev/null ]; then # Label text size(s)
			label_text_sizes+=("${1}") # If -co option is used, will collect all 5 CARET inputs
		elif [ "${#chk_label_pos[@]}" -gt '0' ] && [ "${read_literal}" == 'no' 2>/dev/null ]; then # Label position(s)
			label_poss+=("${1}")
		elif [ "${#chk_color_txt[@]}" -gt '0' ] && [ "${read_literal}" == 'no' 2>/dev/null ]; then
			if [ -z "${label_text_color}" ]; then # First input is text color
				label_text_color="${1}" # Label text color
			else # Second input is background color
				label_bg_color="${1}" # Label background color
			fi
		else # output label(s)
			output_labels+=("${1}")
		fi
		
		read_literal='no' # Do not include subsequent special values in label
	elif [ "${left_in}" == 'yes' 2>/dev/null ]; then # -left (Left hemisphere CARET files)
		custom_input_files '-left' "${1}"  # (1) Option, (2) User input
	elif [ "${right_in}" == 'yes' 2>/dev/null ]; then # -right (Right hemisphere CARET files)
		custom_input_files '-right' "${1}" # (1) Option, (2) User input
	elif [ "${rm_in}" == 'yes' 2>/dev/null ]; then # -rm (Remove unwanted output files)
		if [ "${1}" == "${rm_all_keyword}" 2>/dev/null ]; then
			rm_imgs='yes' # Overwrite individual images if composite image is created
		else # Invalid input (${rm_all_keyword})
			bad_inputs+=("INVALID-INPUT:USE-${rm_all_keyword}_-rm:${1}")
		fi
	elif [ "${t_in}" == 'yes' 2>/dev/null ]; then # -t (Threshold values)
		chk_t=$(echo "${1}" |awk '{print ($1 >= -1000000 && $1 <= 1000000)}') # 1 = valid, 0 = invalid
		if [ "${chk_t}" -eq '1'  2>/dev/null ]; then # threshold
			in_thresh+=("${1}")
		else # Invalid input (-1000000 - 1000000 is arbitrarily large range)
			bad_inputs+=("INVALID-THRESHOLD-VALUE_-t:${1}")
		fi
		
		if [ "${#in_thresh[@]}" -eq '2' ]; then
			t_in='no' # Reset value
		fi # Only allow 2 values (minimum and maximum)
	elif [ "${1:0:1}" == '-' 2>/dev/null ]; then # invalid input option
		bad_inputs+=("INVALID_OPTION:${1}")
	else # Input volume or output image
		volume_check=($(echo "${1}" |grep -E $(printf "%s${IFS}" ${volume_exts[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed -e 's/|/$|/g' -e 's/\$|$//g')))
		if [ "${#volume_check[@]}" -eq '1' ]; then
			in_vol="${volume_check[0]}"
			if [ -f "${in_vol}" ]; then
				input_vols+=("${volume_check[0]}")
			else # Missing file
				bad_inputs+=("MISSING-INPUT-VOLUME:${1}")
			fi
		else # collect output image names
			output_images+=("${1}")
		fi
	fi
} # option_eval

activate_options () { # Activate input options
	# Reset option values
	a_in='no'     # Algorithm
	b_in='no'     # Display brain
	c_in='no'     # Crop image dimensions
	cc_in='no'    # Composite image configuration
	d_in='no'     # Raw image dimensions
	f_in='no'     # Force overwrite keywords
	l_in='no'     # Output label
	left_in='no'  # Custom CARET files (left hemisphere)
	right_in='no' # Custom CARET files (right hemisphere)
	rm_in='no'    # Remove files keywords
	t_in='no'     # Threshold values
	
	if [ "${1}" == '-a' ]; then
	 	a_in='yes'             # Read in user input (algorithm)
	elif [ "${1}" == '-b' ]; then
	 	b_in='yes'             # Read in user input (brain output)
	elif [ "${1}" == '-c' ]; then
	 	crop_imgs='yes'        # Crop raw images
	 	c_in='yes'             # Read in user input (crop image dimensions)
	elif [ "${1}" == '-cc' ]; then
	 	create_comp='yes'      # Create composite image
	 	cc_in='yes'            # Read in user input (composite image)
	elif [ "${1}" == '-ccn' ]; then
	 	create_comp='no'       # Do NOT create composite image
	 	cc_in='yes'            # Read in user input (composite image [ignored])
	 elif [ "${1}" == '-cn' ]; then
	 	crop_imgs='no'         # Do NOT crop raw images
	 	c_in='yes'             # Read in user input (crop image dimensions [ignored])
	 elif [ "${1}" == '-co' ]; then
	 	caret_only='yes'       # Only use caret commands
	elif [ "${1}" == '-cs' ]; then
		clear_screen='no'      # Do NOT clear screen at start
	elif [ "${1}" == '-d' ]; then
	 	d_in='yes'             # Read in user input (raw image dimensions)
	elif [ "${1}" == '-f' ]; then
		force_ow_imgs='yes'    # Overwrite files
		f_in='yes'             # Read in user input (Search for ${rm_all_keyword})
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'    # Display help message
	elif [ "${1}" == '-l' ]; then
		l_in='yes'             # Read in user input (output label)
		if [ "${include_label}" == 'yes' 2>/dev/null ]; then
			read_literal='yes' # Include next value in output label
		fi
		include_label='yes'    # Include label
	elif [ "${1}" == '-left' ]; then
		left_in='yes'          # Read in user input CARET files (left hemisphere)
	elif [ "${1}" == '-mkdir' ]; then
		create_dir='yes'       # Create output folder
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no'   # Do NOT display messages in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'      # Do NOT display exit message
	elif [ "${1}" == '-nt' ]; then
		show_time='no'         # Do NOT display script process time
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'      # Open this script
	elif [ "${1}" == '-right' ]; then
		right_in='yes'         # Read in user input CARET files (right hemisphere)
	elif [ "${1}" == '-rm' ]; then
		rm_misc='yes'          # Remove individual images if composite
		rm_in='yes'            # Read in user input (Search for ${rm_all_keyword})
	elif [ "${1}" == '-s' ]; then
		suppress_msg='yes'     # Do NOT display parameter verification message at start
	elif [ "${1}" == '-t' ]; then
		t_in='yes'             # Add threshold values
		thresh='yes'           # Threshold input
	elif [ "${1}" == '-v' ]; then
		view_image='yes'       # Open composite image
	else # if option is not defined here (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

awk_product () { # Multiply all inputs
	input_numbers=($(printf '%s\n' ${@} |grep '[0-9]')) # Only include values with digit(s)
	
	if [ "${#input_numbers[@]}" -eq '0' ]; then # If no inputs, return '0'
		awk_final_value='0' # if no valid inputs, then return 0
	else # add inputs together
		input_char_check=$(echo ${input_numbers[@]} |sed 's@ @+@g') # check if input characters > ${max_chars}
		if [ "${#input_char_check}" -gt "${max_chars}" ]; then # Use loop for large input
			index_count='0' # begin with first index
			until [ -z "${input_numbers[${index_count}]}" ]; do # Add values until array index is empty
				input_char_check=$(echo "${awk_final_value}*${input_numbers[@]:${index_count}:${nums_per_loop}}" |sed 's@ @+@g') # check if input characters > ${max_chars}
				if [ "${#input_char_check}" -gt "${max_chars}" ]; then
					if [ "${nums_per_loop}" -gt '1' ]; then # Reduce number of inputs to avoid error
						nums_per_loop=$((${nums_per_loop} - 1))
					else # Single input too large for calculation
						awk_final_value='ERROR' # Return 'ERROR'
						break # break out of loop
					fi
				else # Add values to ${awk_final_value}
					awk_final_value=$(eval "echo |awk '{print $(echo ${awk_final_value} ${input_numbers[@]:${index_count}:${nums_per_loop}} |sed 's@ @*@g')}' OFMT='%0.${decimal_places}f'")
					index_count=$((${index_count} + ${nums_per_loop}))
				fi
			done
		else
			awk_final_value=$(eval "echo |awk '{print $(echo ${input_numbers[@]} |sed 's@ @*@g')}' OFMT='%0.${decimal_places}f'")
			# e.g.: echo |awk '{print 3.2*-9.8*9.23}' OFMT='%0.2f' # change decimal places
		fi
	fi
	
	echo "${awk_final_value}"
} # awk_product

color_formats () { # Print colorful terminal text
	if [ "${activate_colors}" == 'yes' 2>/dev/null ]; then
		whi=$(tput setab 0; tput setaf 7) # Black background, white text
		red=$(tput setab 0; tput setaf 1) # Black background, red text
		ora=$(tput setab 0; tput setaf 3) # Black background, orange text
		gre=$(tput setab 0; tput setaf 2) # Black background, green text
		blu=$(tput setab 0; tput setaf 4) # Black background, blue text
		pur=$(tput setab 0; tput setaf 5) # Black background, purple text
		formatreset=$(tput sgr0)          # Reset to default terminal settings
	fi
} # color_formats

create_label () { # Add label to image
	in_label_out="${1}"  # Output image
	in_label_text="${2}" # Label
	in_label_size="${3}" # Label text size
	in_label_pos="${4}"  # Label position
	
	if [ "${include_label}" == 'yes' 2>/dev/null ] && [ -f "${in_label_out}" ]; then # Add label to image
		if [ "${caret_only}" == 'yes' 2>/dev/null ]; then # CARET
			if [ "${#label_text_sizes[@]}" -eq "${#def_caret_label_options[@]}" ]; then # User values
				"${cmd_caret_command}" -image-insert-text "${in_label_out}" "${in_label_out}" $(printf "%s${IFS}" ${label_text_sizes[@]}) "${in_label_text}"
			else # Use default values
				"${cmd_caret_command}" -image-insert-text "${in_label_out}" "${in_label_out}" $(printf "%s${IFS}" ${def_caret_label_options[@]}) "${in_label_text}"
			fi
		else # ImageMagick
 			"${cmd_convert}" -background "${label_bg_color}" -pointsize "${in_label_size}" \
 				-fill "${label_text_color}" label:"${in_label_text}" miff:- |"${cmd_composite}" \
 				-gravity "${in_label_pos}" - "${in_label_out}" "${in_label_out}"
 		fi
	fi
} # create_label

custom_input_files () { # User input custom files
	which_hemi="${1}" # -left, -right
	chk_custom="${2}" # User input file
	
	chk_coord=$(echo "${chk_custom}" |grep "${coord_ext}$")
	chk_scene=$(echo "${chk_custom}" |grep "${scene_ext}$")
	chk_spec=$(echo "${chk_custom}" |grep "${spec_ext}$")
	chk_topo=$(echo "${chk_custom}" |grep "${topo_ext}$")
	
	if ! [ -f "${chk_custom}" ]; then # Missing file
		bad_inputs+=("MISSING-INPUT-FILE_${which_hemi}:${chk_custom}")
	else # Check CARET files
		if ! [ -z "${chk_coord}" ]; then # First '.coord' input is mapping file, second is display
			if [ "${which_hemi}" == '-left' 2>/dev/null ]; then
				left_map_files+=($(mac_readlink "${chk_custom}"))
			else # Right hemisphere
				right_map_files+=($(mac_readlink "${chk_custom}"))
			fi
		elif ! [ -z "${chk_topo}" ]; then # Topology files
			if [ "${which_hemi}" == '-left' 2>/dev/null ]; then
				left_topo_file=$(mac_readlink "${chk_custom}")
			else # Right hemisphere
				right_topo_file=$(mac_readlink "${chk_custom}")
			fi
		elif ! [ -z "${chk_scene}" ]; then # Scene file (whole brain)
			scene=$(mac_readlink "${chk_custom}")
		elif ! [ -z "${chk_spec}" ]; then # Specification file (whole brain)
			spec=$(mac_readlink "${chk_custom}")
		else # Invalid CARET file
			bad_inputs+=("INVALID-CARET-FILE_${which_hemi}:${chk_custom}")
		fi # if ! [ -z "${chk_coord}" ]
	fi # if ! [ -f "${chk_custom}" ]
} # custom_input_files

display_values () { # Display output with numbers
	if [ "${#@}" -gt '0' ]; then
		val_count=($(seq 1 1 ${#@}))
		vals_and_count=($(paste -d "${IFS}" <(printf "%s${IFS}" ${val_count[@]}) <(printf "%s${IFS}" ${@})))
		printf "${pur}[${ora}%s${pur}] ${gre}%s${IFS}${whi}" ${vals_and_count[@]}
	fi
} # display values

get_caret_path () { # Determine default CARET file paths
	def_dir="${1}"  # Default folder path
	def_file="${2}" # Default filename
	
	chk_path="${def_dir}/${def_file}"
	if [ -f "${chk_path}" ]; then
		echo "${chk_path}" # Default path
	else # Missing default path, find file instead
		search_file=($(find "${caret_dir}" -type f -name "${def_file}"))
		if [ "${#search_file[@]}" -eq '0' ]; then
			bad_inputs+=("MISSING-DEFAULT-FILE:${chk_path}")
		else # Use first file
			echo "${search_file[0]}"
		fi
	fi # if [ -f "${chk_path}" ]
} # get_caret_path

link_files () { # Remove old links and create new ones
	in_link="${1}"
	out_link="${2}"
	
	if [ -L "${out_link}" ]; then
		rm "${out_link}" # Remove old link
	fi
	
	if [ -f "${in_link}" ]; then		
		ln -s $(mac_readlink "${in_link}") $(mac_readlink "${out_link}")
	fi
} # link_files

mac_readlink () { # Get absolute path of a file (mac and linux compatible)
	dir_mac=$(dirname "${1}")   # Directory path
	file_mac=$(basename "${1}") # Filename
	wd_mac=$(pwd) # Working directory path

	if [ -d "${dir_mac}" ]; then
		cd "${dir_mac}"
		echo "$(pwd)/${file_mac}" # Print full path
		cd "${wd_mac}" # Change back to original directory
	else
		echo "${1}" # Print input
	fi
} # mac_readlink

open_text_editor () { # Opens input file in background (GUI text editors only)
	open_file="${1}"  # Input file
	valid_editor='no' # Remains 'no' until command is valid
	
	if [ -f "${open_file}" ]; then # If input file exists
		for i in ${!text_editors[@]}; do # Loop through indices
			eval "${text_editors[${i}]} ${open_file} 2>/dev/null &" # eval for complex commands
			pid="$!" # Background process ID
			check_pid=($(ps "${pid}" |grep "${pid}")) # Check if pid is running
			
			if [ "${#check_pid[@]}" -gt '0' ]; then
				valid_editor='yes'
				break
			fi # Break loop when valid command is found
		done

		if [ "${valid_editor}" == 'no' 2>/dev/null ]; then
			echo "${red}NO VALID TEXT EDITOR COMMANDS IN ${ora}text_editors ${red}ARRAY:${whi}"
			printf "${ora}%s${IFS}${whi}" ${text_editors[@]}
			exit_message 99 -nh -nm -nt
		fi
	else # Missing input file
		echo "${red}MISSING FILE: ${ora}${open_file}${whi}"
	fi # if [ -f "${open_file}" ]; then
} # open_text_editor

vital_file () { # Exit script if missing file
	for vitals; do
		if ! [ -e "${vitals}" 2>/dev/null ]; then
			bad_files+=("${vitals}")
		fi
	done
	
	if [ "${#bad_files[@]}" -gt '0' ]; then
		echo "${red}MISSING ESSENTIAL FILE(S):${whi}"
		printf "${pur}%s${IFS}${whi}" ${bad_files[@]}
		exit_message 98 -nh -nm -nt
	fi
} # vital_file

#-------------------------------- MESSAGES ---------------------------------#
exit_message () { # Script exit message
	if [ -z "${1}" 2>/dev/null ] || ! [ "${1}" -eq "${1}" 2>/dev/null ]; then
		exit_type='0'
	else
		exit_type="${1}"
	fi
	
	if [ "${exit_type}" -ne '0' ]; then
		suggest_help='yes'
	fi
	
	for exit_inputs; do
		if [ "${exit_inputs}" == '-nh' 2>/dev/null ]; then
			suggest_help='no'
		elif [ "${exit_inputs}" == '-nt' 2>/dev/null ]; then
			show_time='no'
		elif [ "${exit_inputs}" == '-nm' 2>/dev/null ]; then
			display_exit='no'
		fi
	done
	
	wait # Wait for background processes to finish

	# Suggest help message
	if [ "${suggest_help}" == 'yes' 2>/dev/null ]; then
		echo "${ora}FOR HELP: ${gre}${script_path} -h${whi}"
	fi
	
	# Display exit message
	if ! [ "${display_exit}" == 'no' 2>/dev/null ]; then # Exit message
		echo "${pur}EXITING: ${ora}${script_path}${whi}"
	fi
	
	# Display script process time
	if [ "${show_time}" == 'yes' 2>/dev/null ]; then # Script time message
		time_func 2>/dev/null
	fi
	
	printf "${formatreset}\n"
	IFS="${IFS_old}" # Reset IFS
	exit "${exit_type}"
} # exit_message

time_func () { # Script process time calculation
	func_end_time=$(date +%s) # Time in seconds
	input_time="${1}"
	valid_time='yes'
	
	if ! [ -z "${input_time}" ] && [ "${input_time}" -eq "${input_time}" 2>/dev/null ]; then
		func_start_time="${input_time}"
	elif ! [ -z "${start_time}" ] && [ "${start_time}" -eq "${start_time}" 2>/dev/null ]; then
		func_start_time="${start_time}"
	else # If no integer input or 'start_time' undefined
		valid_time='no'
	fi
	
	if [ "${valid_time}" == 'yes' ]; then
		process_time=$((${func_end_time} - ${func_start_time}))
		days=$((${process_time} / 86400))
		hours=$((${process_time} % 86400 / 3600))
		mins=$((${process_time} % 3600 / 60))
		secs=$((${process_time} % 60))
	
		if [ "${days}" -gt '0' ]; then 
			echo "PROCESS TIME: ${days} day(s) ${hours} hour(s) ${mins} minute(s) ${secs} second(s)"
		elif [ "${hours}" -gt '0' ]; then
			echo "PROCESS TIME: ${hours} hour(s) ${mins} minute(s) ${secs} second(s)"
		elif [ "${mins}" -gt '0' ]; then
			echo "PROCESS TIME: ${mins} minute(s) ${secs} second(s)"
		else
			echo "PROCESS TIME: ${secs} second(s)"
		fi
	else # Unknown start time
		echo "UNKNOWN PROCESS TIME"
	fi # if [ "${valid_time}" == 'yes' ]
} # time_func

#---------------------------------- CODE -----------------------------------#
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

for inputs; do # Reads through all inputs
	option_eval "${inputs}"
done

if ! [ "${clear_screen}" == 'no' 2>/dev/null ]; then
	clear     # Clears screen unless input option: '-cs'
fi

color_formats # Activate or prevent colorful output

# Display help message or open script
if [ "${activate_help}" == 'yes' 2>/dev/null ]; then # '-h' or '--help'
	usage # Display help message
elif [ "${open_script}" == 'yes' 2>/dev/null ]; then # '-o' or '--open'
	open_text_editor "${script_path}" # Open script
	exit_message 0 -nm -nt
fi

# Exit script if invalid inputs
if [ "${#bad_inputs[@]}" -gt '0' ]; then
	clear
	echo "${red}INVALID INPUT:${whi}"
	display_values ${bad_inputs[@]}
	exit_message 1 -nt
fi

#---- CARET5/ImageMagick Commands ----#
cmd_caret_command=$(which 'caret_command' 2>/dev/null)
cmd_composite=$(which 'composite' 2>/dev/null)
cmd_convert=$(which 'convert' 2>/dev/null)
cmd_montage=$(which 'montage' 2>/dev/null)

if [ -z "${cmd_caret_command}" ]; then
	echo "${red}MISSING COMMAND: ${ora}caret_command${whi}"
	echo "${ora}DOWNLOAD CARET: ${gre}${caret_link}${whi}"
	echo "${ora}DOWNLOAD CARET_TUTORIAL_SEPT06: ${gre}${caret_tutorial_link}${whi}"
	echo "${ora}EXPORT PATH IN ~/.bash_profile FILE. ${pur}EXAMPLE${whi}:"
	echo "${pur}"'export PATH=$PATH:/Applications/caret/bin_macosx64'"${whi}"
	exit_message 2 -nt
fi

if ! [ "${caret_only}" == 'yes' 2>/dev/null ]; then # Options require ImageMagick
	if [ -z "${cmd_composite}" ] || [ -z "${cmd_montage}" ] || [ -z "${cmd_convert}" ]; then
		echo "${red}MISSING COMMAND(S): ${ora}composite${whi}, ${ora}convert${whi}, ${ora}montage${whi}"
		echo "${ora}DOWNLOAD IMAGE MAGICK: ${gre}${image_magick_link}${whi}"
		echo "${ora}OR INPUT ${pur}-co${ora} OPTION TO ONLY USE CARET COMMANDS${whi}"
		exit_message 3 -nt
	fi
fi

if [ "${#val_coords[@]}" -ne "${#left_coords[@]}" ] || [ "${#val_coords[@]}" -ne "${#right_coords[@]}" ]; then
	echo "${red}ARRAYS MUST BE SAME LENGTH: ${ora}val_coords ${gre}${#val_coords[@]} ${ora}left_coords ${gre}${#left_coords[@]} ${ora}right_coords ${gre}${#right_coords[@]}${whi}"
	exit_message 4 -nt
fi # Use correct coordinate files

# Find CARET Folder based on 'caret_command' location
caret_dirs+=($(dirname $(dirname "${cmd_caret_command}"))) # 2 folders up
caret_dirs=($(printf "%s${IFS}" ${caret_dirs[@]} |awk '!caret_dirs[$0]++')) # Unique folders only

for i in ${!caret_dirs[@]}; do
	chk_dir="${caret_dirs[${i}]}"
	if [ -d "${chk_dir}" ]; then
		caret_dir="${chk_dir}" # Assign 'caret' folder
		caret_data_dir="${caret_dir}/${def_caret_data_dir}"
		caret_map_dir="${caret_data_dir}/${def_caret_map_dir}"
		break # Break out of for-loop
	fi
done

# Assign unspecified files with defaults
if [ -z "${scene}" ] || [ -z "${spec_file}" ] || \
   [ -z "${left_topo_file}" ] || [ -z "${right_topo_file}" ] || \
   [ "${#left_map_files[@]}" -eq '0' ] || [ "${#right_map_files[@]}" -eq '0' ]; then
   
	if [ -z "${caret_dir}" ]; then # If a default file is required, "${caret_dir}" must exist
		echo "${red}COULD NOT FIND '${ora}caret${red}' FOLDER${whi}"
		echo "${red}WRITE PATH IN ${gre}caret_dirs ${red}ARRAY WITHIN SCRIPT${whi}"
		display_values ${caret_dirs[@]}
		exit_message 5 -nh -nt
	fi
	
	if [ -z "${scene}" ]; then
		scene=$(get_caret_path "${caret_map_dir}" "${def_scene}")
	fi
	
	if [ -z "${spec_file}" ]; then
		spec_file=$(get_caret_path "${caret_map_dir}" "${def_spec_file}")
	fi
	
	if [ -z "${left_topo_file}" ]; then
		left_topo_file=$(get_caret_path "${caret_data_dir}" "${def_left_topo_file}")
	fi
	
	if [ -z "${right_topo_file}" ]; then
		right_topo_file=$(get_caret_path "${caret_data_dir}" "${def_right_topo_file}")
	fi
	
	if [ "${#left_map_files[@]}" -eq '0' ]; then
		mapping_left_coord_file=$(get_caret_path "${caret_map_dir}" "${def_mapping_left_coord_file}")
	fi
	
	if [ "${#right_map_files[@]}" -eq '0' ]; then
		mapping_right_coord_file=$(get_caret_path "${caret_map_dir}" "${def_mapping_right_coord_file}")
	fi
fi # [ -z "${scene}" ] || [ -z "${spec_file}" ] || ...

# Left mapping/display files
if [ "${#left_map_files[@]}" -eq '1' ]; then # Use the same mapping and display file
	mapping_left_coord_file="${left_map_files[0]}"
	left_coord="${mapping_left_coord_file}"
elif [ "${#left_map_files[@]}" -gt '1' ]; then
	mapping_left_coord_file="${left_map_files[0]}"
	left_coord="${left_map_files[1]}"
fi

# Right mapping/display files
if [ "${#right_map_files[@]}" -eq '1' ]; then # Use the same mapping and display file
	mapping_right_coord_file="${right_map_files[0]}"
	right_coord="${mapping_right_coord_file}"
elif [ "${#right_map_files[@]}" -gt '1' ]; then
	mapping_right_coord_file="${right_map_files[0]}"
	right_coord="${right_map_files[1]}"
fi

# Assign default values to unspecified inputs
if [ -z "${disp_coord}" ]; then # -b (Display brain)
	if ! [ -z "${left_coord}" ]; then # Use input display if found
		base_coord=$(basename "${left_coord}")
		for i in ${!left_coords[@]}; do # Loop thru valid left coordinate files
			in_coord="${left_coords[${i}]}"
			if [ "${base_coord}" == "${in_coord}" 2>/dev/null ]; then
				disp_coord="${val_coords[${i}]}"
				break # Break out of for-loop
			fi
		done
	fi

	if [ -z "${disp_coord}" ]; then
		disp_coord="${def_coord}" # Use default if input is still unknown
	fi 
fi # if [ -z "${disp_coord}" ]

if [ -z "${left_coord}" ] || [ -z "${right_coord}" ]; then

	for i in ${!val_coords[@]}; do # Loop to match coordinate files with "${disp_coord}"
		in_brain="${val_coords[${i}]}"
		
		if [ "${in_brain}" == "${disp_coord}" 2>/dev/null ]; then
			if [ -z "${left_coord}" ]; then
				left_coord=$(get_caret_path "${caret_map_dir}" "${left_coords[${i}]}") # Left coordinate display file
			fi
			
			if [ -z "${right_coord}" ]; then
				right_coord=$(get_caret_path "${caret_map_dir}" "${right_coords[${i}]}") # Right coordinate display file
			fi
			
			break # Break out of loop
		fi
	done # for i in ${!val_coords[@]}
fi # if [ -z "${left_coord}" ] || [ -z "${right_coord}" ]

if [ "${#bad_inputs[@]}" -gt '0' ]; then
	display_values ${bad_inputs[@]}
	echo "${red}COULD NOT FIND DEFAULT FILES${whi}"
	echo "${ora}MAY NEED TO CHANGE DEFAULT FOLDER VALUES WITHIN SCRIPT${whi}:"
	echo "${whi}'${ora}def_caret_data_dir${whi}': ${gre}${def_caret_data_dir}${whi}"
	echo "${whi}'${ora}def_caret_map_dir${whi}': ${gre}${def_caret_map_dir}${whi}"
	vital_file "${caret_data_dir}" "${caret_map_dir}"
	exit_message 6 -nt
fi

if [ -z "${left_coord}" ] || [ -z "${right_coord}" ]; then
	echo "${red}COULD NOT DETERMINE LEFT AND/OR RIGHT COORDINATE FILES${whi}"
	echo "${ora}Left : ${gre}${left_coord}${whi}"
	echo "${ora}Right: ${gre}${right_coord}${whi}"
	exit_message 7 -nt
fi # If default brain not in array: 'val_coords'

caret_map_dir=$(dirname "${spec_file}") # Re-assign foldername if not default value

if [ -z "${algo}" ]; then # -a (Brain mapping algorithm)
	algo="${def_algo}"
fi

if [ "${#dims[@]}" -eq '0' ]; then # -d (raw output image dimensions)
	dims=($(printf "%s${IFS}" ${def_dims[@]})) # Use printf to avoid $IFS errors
elif [ "${#dims[@]}" -eq '1' ]; then
	dims+=("${dims[0]}") # Create square
fi

dim1="${dims[0]}" # -d: X dimension (raw output image)
dim2="${dims[1]}" # -d: Y dimension (raw output image)

if ! [ "${dim1}" -ge '1' 2>/dev/null ] || ! [ "${dim2}" -ge '1' 2>/dev/null ]; then # -d
	echo "${red}IMAGE PIXEL DIMENSIONS MUST BE POSITIVE INTEGERS: ${gre}${dim1}x${dim2}${whi}"
	exit_message 8 -nt
fi

if [ "${#comp_order[@]}" -eq '0' ]; then
	if [ "${disp_coord}" == "${b2}" 2>/dev/null ]; then
		comp_order=($(printf "%s${IFS}" ${def_comp_order_b2[@]})) # Flat brain has different default
	else # Regular order
		comp_order=($(printf "%s${IFS}" ${def_comp_order[@]})) # Use printf to avoid $IFS errors
	fi
fi

if [ "${disp_coord}" == "${b2}" 2>/dev/null ]; then # Flat display brain
	for i in ${!comp_order[@]}; do # Only accept dorsal/ventral inputs for flat brain
		i_pos="${comp_order[${i}]}"
		chk_dv=($(echo "${i_pos}" |grep -E "${left_dor_code}|${right_dor_code}|${left_ven_code}|${right_ven_code}"))
		if [ "${#chk_dv[@]}" -eq '0' ]; then
			echo "${red}ONLY INPUT DORSAL OR VENTRAL VIEWS FOR ${ora}${b2} ${red}DISPLAY BRAIN${whi}"
			display_values ${comp_order[@]}
			exit_message 9 -nt
		fi
	done # for i in ${!comp_order[@]}
fi # if [ "${disp_coord}" == "${b2}" 2>/dev/null ]

if [ "${crop_imgs}" == 'yes' 2>/dev/null ]; then # -c (crop output image)
	tot_crop2=$((${tot_crop_vals} * 2)) # 2 times total crop values
	tot_crop3=$((${tot_crop_vals} * 3)) # 3 times total crop values
	if [ "${#crop_dims[@]}" -eq "${tot_crop_vals}" ]; then # Set all crop dimensions the same
		crop_dims_ap=($(printf "%s${IFS}" ${crop_dims[@]}))
		crop_dims_dv=($(printf "%s${IFS}" ${crop_dims[@]}))
		crop_dims_lm=($(printf "%s${IFS}" ${crop_dims[@]}))
	elif [ "${#crop_dims[@]}" -eq "${tot_crop2}" ]; then # Set first/last different, check middle
		crop_dims_ap=($(printf "%s${IFS}" ${crop_dims[@]:0:"${tot_crop_vals}"}))
		crop_dims_lm=($(printf "%s${IFS}" ${crop_dims[@]:"${tot_crop_vals}":"${tot_crop_vals}"}))
		
		# Check for anterior/posterior inputs
		chk_ap=($(printf "%s${IFS}" ${comp_order[@]} |grep -E "${left_ant_code}|${right_ant_code}|${left_pos_code}|${right_pos_code}"))
		if [ "${#chk_ap[@]}" -eq '0' ]; then # No anterior/posterior values (set to first ${tot_crop_vals})
			crop_dims_dv=($(printf "%s${IFS}" ${crop_dims[@]:0:"${tot_crop_vals}"}))
		else # Anterior/posterior values specified (set to second set of ${tot_crop_vals)
			crop_dims_dv=($(printf "%s${IFS}" ${crop_dims[@]:"${tot_crop_vals}":"${tot_crop_vals}"}))
		fi
	elif [ "${#crop_dims[@]}" -eq "${tot_crop3}" ]; then # Set in order (ant/pos, dor/ven, med/lat)
		crop_dims_ap=($(printf "%s${IFS}" ${crop_dims[@]:0:"${tot_crop_vals}"}))
		crop_dims_dv=($(printf "%s${IFS}" ${crop_dims[@]:"${tot_crop_vals}":"${tot_crop_vals}"}))
		crop_dims_lm=($(printf "%s${IFS}" ${crop_dims[@]:"${tot_crop2}":"${tot_crop_vals}"}))
	elif [ "${#crop_dims[@]}" -eq '0' ]; then # Zero inputs = default
		if [ "${disp_coord}" == "${b1}" 2>/dev/null ]; then # Fiducial default values
			crop_dims_ap=($(printf "%s${IFS}" ${def_b1_crop_ap[@]}))
			crop_dims_dv=($(printf "%s${IFS}" ${def_b1_crop_dv[@]}))
			crop_dims_lm=($(printf "%s${IFS}" ${def_b1_crop_lm[@]}))
		elif [ "${disp_coord}" == "${b2}" 2>/dev/null ]; then # Flat (only appears in dor/ven layouts)
			crop_dims_dv=($(printf "%s${IFS}" ${def_b2_crop_dv[@]}))
		else # Inflate or very-inflated display brain
			crop_dims_ap=($(printf "%s${IFS}" ${def_b3b4_crop_ap[@]}))
			crop_dims_dv=($(printf "%s${IFS}" ${def_b3b4_crop_dv[@]}))
			crop_dims_lm=($(printf "%s${IFS}" ${def_b3b4_crop_lm[@]}))
		fi
	else
		echo "${red}MUST SPECIFY ${ora}${tot_crop_vals}${red}, ${ora}${tot_crop2}${red}, OR ${ora}${tot_crop3} ${red}CROP DIMENSIONS (${pur}-c ${gre}${#crop_dims[@]}${red})${whi}"
		display_values ${crop_dims[@]}
		exit_message 10 -nt
	fi # if [ "${#crop_dims[@]}" -gt "${tot_crop_vals}" ]
	
	# Calculate cropped dimensions (Anterior/Posterior)
	dimX_ap=$(awk_product "${dim1}" "${crop_dims_ap[0]}")
	dimY_ap=$(awk_product "${dim2}" "${crop_dims_ap[1]}")
	lXshift_ap=$(awk_product "${dim1}" "${crop_dims_ap[2]}")
	lYshift_ap=$(awk_product "${dim2}" "${crop_dims_ap[3]}")
	rXshift_ap=$(awk_product "${dim1}" "${crop_dims_ap[4]}")
	rYshift_ap=$(awk_product "${dim2}" "${crop_dims_ap[5]}")
	# Dorsal/Ventral
	dimX_dv=$(awk_product "${dim1}" "${crop_dims_dv[0]}")
	dimY_dv=$(awk_product "${dim2}" "${crop_dims_dv[1]}")
	lXshift_dv=$(awk_product "${dim1}" "${crop_dims_dv[2]}")
	lYshift_dv=$(awk_product "${dim2}" "${crop_dims_dv[3]}")
	rXshift_dv=$(awk_product "${dim1}" "${crop_dims_dv[4]}")
	rYshift_dv=$(awk_product "${dim2}" "${crop_dims_dv[5]}")
	# Lateral/Medial
	dimX_lm=$(awk_product "${dim1}" "${crop_dims_lm[0]}")
	dimY_lm=$(awk_product "${dim2}" "${crop_dims_lm[1]}")
	lXshift_lm=$(awk_product "${dim1}" "${crop_dims_lm[2]}")
	lYshift_lm=$(awk_product "${dim2}" "${crop_dims_lm[3]}")
	rXshift_lm=$(awk_product "${dim1}" "${crop_dims_lm[4]}")
	rYshift_lm=$(awk_product "${dim2}" "${crop_dims_lm[5]}")
fi # if [ "${crop_imgs}" == 'yes' 2>/dev/null ]
	
if [ "${create_comp}" == 'yes' 2>/dev/null ]; then # -cc (create composite image)
	if [ "${#comp_dims[@]}" -eq '0' ]; then
		comp_dims=($(printf "%s${IFS}" ${def_comp_dims[@]})) # Use printf to avoid $IFS errors
	elif [ "${#comp_dims[@]}" -eq '1' ]; then
		comp_dims+=('1') # Autofill with '1'
	fi
	
	dcc1="${comp_dims[0]}" # Composite image dimension 1 (rows)
	dcc2="${comp_dims[1]}" # Composite image dimension 2 (columns)
	if [ "${dcc1}" -eq "${dcc1}" 2>/dev/null ] && [ "${dcc2}" -eq "${dcc2}" 2>/dev/null ]; then
		chk_dcc=$((${dcc1} * ${dcc2})) # Multiply dimensions
	fi
	
	if [ -z "${chk_dcc}" ] || [ "${chk_dcc}" -lt '1' 2>/dev/null ]; then # Invalid dimensions
		echo "${red}INVALID COMPOSITE IMAGE DIMENSIONS: ${gre}${dcc1}x${dcc2} ${pur}-cc${whi}"
		exit_message 11 -nt
	fi
	
	if [ "${#comp_order[@]}" -ne "${chk_dcc}" ]; then
		echo "${red}COMPOSITE IMAGE VALUES MUST MATCH DIMENSIONS: ${gre}${dcc1}x${dcc2} ${red}(${pur}-cc ${gre}${#comp_order[@]}${whi}/${gre}${chk_dcc}${red})${whi}"
		echo "${ora}COMPOSITE IMAGE VALUES:${whi}"
		display_values ${comp_order[@]}
		exit_message 12 -nt
	fi
fi # if [ "${create_comp}" == 'yes' 2>/dev/null ]

if [ "${include_label}" == 'yes' 2>/dev/null ]; then # -l (output image label)	
	if [ "${#output_labels[@]}" -eq '0' ]; then # No label specified
		echo "${red}MUST INCLUDE LABEL WITH ${pur}-l ${red}OPTION${whi}"
		exit_message 13 -nt
	fi
	
	if [ "${#label_text_sizes[@]}" -eq '0' ]; then # Default text size
		label_text_sizes=("${def_text_size}")
	fi

	if [ -z "${label_text_color}" ]; then # Default text color
		label_text_color="${def_text_color}"
	fi
	
	if [ "${#label_poss[@]}" -eq '0' ]; then # Default label position
		label_poss=("${def_label_pos}")
	fi
	
	if [ -z "${label_bg_color}" ]; then # Default background color
		label_bg_color="${def_bg_color}"
	fi
fi # if [ "${include_label}" == 'yes' 2>/dev/null ]

if [ "${thresh}" == 'yes' 2>/dev/null ]; then
	if ! [ "${#in_thresh[@]}" -eq '2' ]; then
		echo "${red}MUST INPUT 2 THRESHOLD VALUES: ${gre}${#in_thresh[@]}${ora}/2${whi}"
		display_values ${in_thresh[@]}
		exit_message 14 -nt
	else # Sort threshold
		sort_thresh=($(printf "%s${IFS}" ${in_thresh[@]} |sort -n))
		min_thresh="${sort_thresh[0]}"
		max_thresh="${sort_thresh[1]}"
	fi
fi

if [ "${#input_vols[@]}" -eq '0' ]; then
	echo "${red}MUST SPECIFY INPUT VOLUME WITH ONE OF THE FOLLOWING EXTENSIONS:${whi}"
	display_values ${volume_exts[@]}
	exit_message 15 -nt
elif [ "${#input_vols[@]}" -eq '1' ]; then # 1 input volume
	input_vol=$(mac_readlink "${input_vols[0]}") # Full path
	base_input_vol=$(basename "${input_vol}")
else # Cannot exceed 1 input volume
	echo "${red}ONLY SPECIFY ONE INPUT VOLUME:${whi}"
	display_values ${input_vols[@]}
	exit_message 16 -nt
fi

if [ "${#output_images[@]}" -eq '0' ]; then
	echo "${red}MUST SPECIFY OUTPUT IMAGE${whi}"
	exit_message 17 -nt
elif [ "${#output_images[@]}" -eq '1' ]; then
	out_rm_ext=$(mac_readlink $(echo "${output_images[0]}" |sed "s/\\${image_ext}$//g")) # Remove extension
	out_image="${out_rm_ext}${image_ext}"
	if [ -f "${out_image}" ] && [ "${force_ow_imgs}" == 'no' 2>/dev/null ]; then
		echo "${red}OUTPUT FILE EXISTS (${ora}use ${pur}-f ${ora}option to overwrite${red}): ${out_image}${whi}"
		exit_message 18 -nt
	else # Check folder
		base_out_image=$(basename "${out_rm_ext}") # Becomes part of filename for metric/scene files
		out_dir=$(dirname "${out_image}")
		if ! [ -d "${out_dir}" ]; then
			if [ "${create_dir}" == 'no' ]; then # -mkdir (Specify option to create folders)
				echo "${red}MISSING FOLDER: ${ora}${out_dir}${whi}"
				exit_message 19 -nt
			else # Create output folder
				mkdir -p "${out_dir}"
				vital_file "${out_dir}"
			fi
		fi # if ! [ -d "${out_dir}" ]
	fi # if [ -f "${output_images[0]}" ] && [ "${force_ow_imgs}" == 'no' 2>/dev/null ]
else
	echo "${red}TOO MANY OUTPUT IMAGES:${whi}"
	display_values ${output_images[@]}
	exit_message 20 -nt
fi # if [ "${#output_images[@]}" -eq '0' ]

# Alert user of parameters before running (-s to suppress)
if ! [ "${suppress_msg}" == 'yes' 2>/dev/null ]; then
	if ! [ "${verify_time}" -ge '1' 2>/dev/null ]; then
		verify_time='1' # Default to '1' to avoid errors
	fi
	# Display values
	echo "${whi}INPUT VOLUME             : ${gre}${base_input_vol}${whi}"
	echo "${whi}OUTPUT FILENAME BASE     : ${gre}${base_out_image}${whi}"
	echo "${whi}OUTPUT DISPLAY BRAIN     : ${gre}${disp_coord}${whi}"
	echo "${ora}CROP IMAGES              : ${gre}${crop_imgs}${whi}" |sed "s@no@${red}no@g"
	
	if [ "${create_comp}" == 'yes' 2>/dev/null ]; then # Show in green with composite dimensions
		echo "${ora}CREATE COMPOSITE         : ${gre}${create_comp} (${ora}${dcc1}${whi}x${ora}${dcc2}${gre})${whi}"
		echo "${ora}REMOVE OUTPUT IMAGES     : ${gre}${rm_imgs}${whi}" |sed "s@no@${red}no@g"
	else # Show in red (individual images will not be removed)
		echo "${ora}CREATE COMPOSITE         : ${red}${create_comp}${whi}" |sed "s@no@${red}no@g"
	fi
	
	if [ "${#output_labels[@]}" -gt '0' ]; then # Display output label(s)
		echo "${pur}LABEL(S):${whi}"
		display_values ${output_labels[@]}
	fi
	
	echo "${ora}REMOVE OUTPUT CARET FILES: ${gre}${rm_misc}${whi}" |sed "s@no@${red}no@g"
	echo "${ora}OVERWRITE OLD IMAGES     : ${gre}${force_ow_imgs}${whi}" |sed "s@no@${red}no@g"
	echo "${ora}OVERWRITE OLD CARET FILES: ${gre}${force_ow_misc}${whi}" |sed "s@no@${red}no@g"
	
	echo "${pur}INDIVIDUAL IMAGE VIEWS:${whi}"
	display_values ${comp_order[@]} # Display image views
	
	echo "${ora}CARET INPUT FILES:${whi}"
	echo "${pur}${scene_ext}${whi}: ${gre}"$(basename "${scene}")"${whi}"
	echo "${pur}${spec_ext}${whi} : ${gre}"$(basename "${spec_file}")"${whi}"
	echo "${ora}LEFT ${pur}${topo_ext}${whi} : ${gre}"$(basename "${left_topo_file}")"${whi}"
	echo "${ora}RIGHT ${pur}${topo_ext}${whi}: ${gre}"$(basename "${right_topo_file}")"${whi}"
	echo "${ora}LEFT MAPPING${whi} : ${gre}"$(basename "${mapping_left_coord_file}")"${whi}"
	echo "${ora}RIGHT MAPPING${whi}: ${gre}"$(basename "${mapping_right_coord_file}")"${whi}"
	echo "${ora}LEFT DISPLAY${whi} : ${gre}"$(basename "${left_coord}")"${whi}"
	echo "${ora}RIGHT DISPLAY${whi}: ${gre}"$(basename "${right_coord}")"${whi}"
	
	echo "${ora}INPUT ${gre}ctrl${ora}+${gre}c ${ora}TO CRASH${whi}"
	printf "${ora}STARTING IN: ${whi}"
	for i in $(seq "${verify_time}" -1 1); do # Loop thru seconds
		printf "${pur}${i} ${whi}" # Display number of seconds before processing
		sleep 1 # Wait 1 second
	done
fi # if ! [ "${suppress_msg}" == 'yes' 2>/dev/null ]
echo "${ora}PROCESSING: ${gre}${base_out_image}${whi}" # Alert user of script start

out_spec="${base_out_image}${spec_ext}"
temp_out_spec="${caret_map_dir}/${out_spec}" # Must be in CARET mapping folder
final_out_spec="${out_dir}/${out_spec}"

cp "${spec_file}" "${temp_out_spec}" # Do not overwrite original spec file!
vital_file "${temp_out_spec}"
#------------------------------------  map contrasts to caret surfaces ------------------------------------
for i in ${!comp_order[@]}; do # Loop thru codes
	in_code="${comp_order[${i}]}"
	if [ "${in_code}" == "${left_ant_code}" 2>/dev/null ] || [ "${in_code}" == "${left_dor_code}" 2>/dev/null ] || \
	   [ "${in_code}" == "${left_lat_code}" 2>/dev/null ] || [ "${in_code}" == "${left_med_code}" 2>/dev/null ] || \
	   [ "${in_code}" == "${left_pos_code}" 2>/dev/null ] || [ "${in_code}" == "${left_ven_code}" 2>/dev/null ]; then
		direct="${left}" # Left hemisphere
		coord_file="${left_coord}"
		map_coord_file="${mapping_left_coord_file}"
		topo_file="${left_topo_file}"
		
		if [ "${in_code}" == "${left_ant_code}" 2>/dev/null ]; then
			region="${l_ant}"
			c_pos="${caret_ant}" # CARET position
			dim_crop="${dimX_ap}x${dimY_ap}+${lXshift_ap}+${lYshift_ap}"
		elif [ "${in_code}" == "${left_dor_code}" 2>/dev/null ]; then
			region="${l_dor}"
			c_pos="${caret_dor}" # CARET position
			dim_crop="${dimX_dv}x${dimY_dv}+${lXshift_dv}+${lYshift_dv}"
		elif [ "${in_code}" == "${left_lat_code}" 2>/dev/null ]; then
			region="${l_lat}"
			c_pos="${caret_lat}" # CARET position
			dim_crop="${dimX_lm}x${dimY_lm}+${lXshift_lm}+${lYshift_lm}"
		elif [ "${in_code}" == "${left_med_code}" 2>/dev/null ]; then
			region="${l_med}"
			c_pos="${caret_med}" # CARET position
			dim_crop="${dimX_lm}x${dimY_lm}+${rXshift_lm}+${rYshift_lm}" # Flipped
		elif [ "${in_code}" == "${left_pos_code}" 2>/dev/null ]; then
			region="${l_pos}"
			c_pos="${caret_pos}" # CARET position
			dim_crop="${dimX_ap}x${dimY_ap}+${rXshift_ap}+${rYshift_ap}" # Flipped
		elif [ "${in_code}" == "${left_ven_code}" 2>/dev/null ]; then
			region="${l_ven}"
			c_pos="${caret_ven}" # CARET position
			dim_crop="${dimX_dv}x${dimY_dv}+${rXshift_dv}+${rYshift_dv}" # Flipped
		fi # if [ "${in_code}" == "${left_ant_code}" 2>/dev/null ]
		
	elif [ "${in_code}" == "${right_ant_code}" 2>/dev/null ] || [ "${in_code}" == "${right_dor_code}" 2>/dev/null ] || \
	     [ "${in_code}" == "${right_lat_code}" 2>/dev/null ] || [ "${in_code}" == "${right_med_code}" 2>/dev/null ] || \
	     [ "${in_code}" == "${right_pos_code}" 2>/dev/null ] || [ "${in_code}" == "${right_ven_code}" 2>/dev/null ]; then
			direct="${right}" # Left hemisphere
			coord_file="${right_coord}"
			map_coord_file="${mapping_right_coord_file}"
			topo_file="${right_topo_file}"
			
		if [ "${in_code}" == "${right_ant_code}" 2>/dev/null ]; then
			region="${r_ant}"
			c_pos="${caret_ant}" # CARET position
			dim_crop="${dimX_ap}x${dimY_ap}+${rXshift_ap}+${rYshift_ap}"
		elif [ "${in_code}" == "${right_dor_code}" 2>/dev/null ]; then
			region="${r_dor}"
			c_pos="${caret_dor}" # CARET position
			dim_crop="${dimX_dv}x${dimY_dv}+${rXshift_dv}+${rYshift_dv}"
		elif [ "${in_code}" == "${right_lat_code}" 2>/dev/null ]; then
			region="${r_lat}"
			c_pos="${caret_lat}" # CARET position
			dim_crop="${dimX_lm}x${dimY_lm}+${rXshift_lm}+${rYshift_lm}"
		elif [ "${in_code}" == "${right_med_code}" 2>/dev/null ]; then
			region="${r_med}"
			c_pos="${caret_med}" # CARET position
			dim_crop="${dimX_lm}x${dimY_lm}+${lXshift_lm}+${lYshift_lm}" # Flipped
		elif [ "${in_code}" == "${right_pos_code}" 2>/dev/null ]; then
			region="${r_pos}"
			c_pos="${caret_pos}" # CARET position
			dim_crop="${dimX_ap}x${dimY_ap}+${lXshift_ap}+${lYshift_ap}" # Flipped
		elif [ "${in_code}" == "${right_ven_code}" 2>/dev/null ]; then
			region="${r_ven}"
			c_pos="${caret_ven}" # CARET position
			dim_crop="${dimX_dv}x${dimY_dv}+${lXshift_dv}+${lYshift_dv}" # Flipped
		fi # if [ "${in_code}" == "${right_ant_code}" 2>/dev/null ]
	else # Script error (debugging)
		echo "${red}ERROR: '${ora}comp_order${red}' ${LINENO}${whi}"
		exit_message 21 -nt
	fi

	final_out_scene="${out_dir}/${base_out_image}${region}${scene_ext}"
	final_out_img="${out_dir}/${base_out_image}${region}${image_ext}"
	final_out_met="${out_dir}/${base_out_image}${region}${metric_ext}"
	col_name="${base_out_image}${region}" # Metric file column name
	
	if ! [ -f "${final_out_met}" ] || [ "${force_ow_misc}" == 'yes' 2>/dev/null ]; then
		# map the input volume to the caret brain surface
		"${cmd_caret_command}" -volume-map-to-surface "${map_coord_file}" "${topo_file}" "" "${final_out_met}" "${algo}" "${input_vol}"
		vital_file "${final_out_met}"
		# change the name of the data column in the metric file
		"${cmd_caret_command}" -metric-set-column-name "${final_out_met}" "1" "${col_name}"
		# Threshold volume
		if [ "${thresh}" == 'yes' 2>/dev/null ]; then # Threshold volumes
			"${cmd_caret_command}" -metric-clustering "${map_coord_file}" "${topo_file}" "${final_out_met}" "${final_out_met}" "-${min_thresh}" "-${max_thresh}" "${min_thresh}" "${max_thresh}" 'ANY_SIZE' '1' '1'
		fi
	fi # if ! [ -f "${final_out_met}" ] || [ "${force_ow_misc}" == 'yes' 2>/dev/null ]
	
	if ! [ -f "${final_out_spec}" ] || [ "${force_ow_misc}" == 'yes' 2>/dev/null ]; then
		# add metric file to temporary spec file
		"${cmd_caret_command}" -spec-file-add "${temp_out_spec}" metric_file "${final_out_met}"
	else # Copy final file to temporary folder (for image processing)
    	cp "${final_out_spec}" "${temp_out_spec}"
    fi
    
    if ! [ -f "${final_out_scene}" ] || [ "${force_ow_misc}" == 'yes' 2>/dev/null ]; then
		# Create a scene
		"${cmd_caret_command}" -scene-create "${temp_out_spec}" "${scene}" "${final_out_scene}" "${col_name}" -surface-overlay \
	 	"PRIMARY" "METRIC" "${col_name}" "${col_name}" -window-surface-files "WINDOW_MAIN" "${dim1}" "${dim2}" \
    	"${coord_file}" "${topo_file}" "${c_pos}"
    	vital_file "${final_out_scene}"
    fi
    
    if ! [ -f "${final_out_image}" ] || [ "${force_ow_imgs}" == 'yes' 2>/dev/null ]; then
    	# Create image
		"${cmd_caret_command}" -show-scene "${temp_out_spec}" "${final_out_scene}" "${col_name}" -image-file "${final_out_img}" '1'
		vital_file "${final_out_img}"
		
		# Edit images
		if [ "${crop_imgs}" == 'yes' 2>/dev/null ] && ! [ -z "${cmd_convert}" ]; then # ImageMagick only
			"${cmd_convert}" -crop "${dim_crop}" "${final_out_img}" "${final_out_img}"
			vital_file "${final_out_img}"
		fi
		
		label_count='0' # Reset value 
		for j in ${!output_labels[@]}; do # Loop thru output labels
			label_count=$((${label_count} + 1))
			output_label="${output_labels[${j}]}"
			j_in="${j}" # Label index that matches input image
			
			if [ "${create_comp}" == 'yes' 2>/dev/null ]; then
				if [ "${j}" -eq '0' ]; then
					continue # First label/options are for composite image (if created)
				else # Subtract 1 so label matches input image
					j_in=$((${j_in} - 1))
				fi
			fi 
			
			if [ "${j_in}" -ne "${i}" ]; then
				continue # Output label must match input image
			fi
		
			if [ "${#label_text_sizes[@]}" -lt "${label_count}" ]; then
				label_text_size="${label_text_sizes[@]:(-1)}" # Use last value
			else
				label_text_size="${label_text_sizes[${j}]}"
			fi
			
			if [ "${#label_poss[@]}" -lt "${label_count}" ]; then
				label_pos="${label_poss[@]:(-1)}" # Use last value
			else
				label_pos="${label_poss[${j}]}"
			fi
			
			create_label "${final_out_img}" "${output_labels[${j}]}" "${label_text_size}" "${label_pos}"
			break # Only label once
		done # for j in ${!output_labels[@]}
	fi
	
	final_comp_order+=("${final_out_img}") # Remove (if specified)
	final_out_caret_files+=("${final_out_met}" "${final_out_spec}" "${final_out_scene}") # Remove (if specified)
done # for i in ${!comp_order[@]}

if [ "${create_comp}" == 'yes' 2>/dev/null ]; then	
	# make a composite image with the individual caret brain images
	
	if [ "${caret_only}" == 'yes' 2>/dev/null ]; then # Combine with caret command
		"${cmd_caret_command}" -image-combine "${dcc1}" "${out_image}" $(printf "%s${IFS}" ${final_comp_order[@]})
	else # Combine with ImageMagick
		"${cmd_montage}" $(printf "%s${IFS}" ${final_comp_order[@]}) -tile "${dcc1}"x"${dcc2}" -geometry +0+0 "${out_image}" # caret_command created errors
	fi
	
	create_label "${out_image}" "${output_labels[0]}" "${label_text_sizes[0]}" "${label_poss[0]}"

	# Re-process if image combine error
	if [ "$?" -eq '0' ] && [ -f "${out_image}" ]; then
    	echo "${gre}CREATED: ${ora}${out_image}${whi}"
	else
    	echo "${red}NOT CREATED: ${ora}${out_image}${whi}"
	fi
fi # if [ "${create_comp}" == 'yes' 2>/dev/null ]

if [ "${rm_imgs}" == 'yes' 2>/dev/null ] && [ "${create_comp}" == 'yes' 2>/dev/null ]; then
	rm $(printf "%s${IFS}" ${final_comp_order[@]}) 2>/dev/null
fi

if [ "${rm_misc}" == 'yes' 2>/dev/null ]; then # Remove files and old links
	rm $(printf "%s${IFS}" "${temp_out_spec}" ${final_out_caret_files[@]}) 2>/dev/null
	link_files '-rm' "${out_dir}/"$(basename "${right_topo_file}")
	link_files '-rm' "${out_dir}/"$(basename "${left_topo_file}")
	link_files '-rm' "${out_dir}/"$(basename "${mapping_right_coord_file}")
	link_files '-rm' "${out_dir}/"$(basename "${mapping_left_coord_file}")
	link_files '-rm' "${out_dir}/"$(basename "${left_coord}")
	link_files '-rm' "${out_dir}/"$(basename "${right_coord}")
else # Move temporary '.spec' file to output folder and create links
	mv "${temp_out_spec}" "${out_dir}" 2>/dev/null
	# Link CARET input files to view in GUI later
	link_files "${right_topo_file}" "${out_dir}/"$(basename "${right_topo_file}")
	link_files "${left_topo_file}" "${out_dir}/"$(basename "${left_topo_file}")
	link_files "${mapping_right_coord_file}" "${out_dir}/"$(basename "${mapping_right_coord_file}")
	link_files "${mapping_left_coord_file}" "${out_dir}/"$(basename "${mapping_left_coord_file}")
	link_files "${left_coord}" "${out_dir}/"$(basename "${left_coord}")
	link_files "${right_coord}" "${out_dir}/"$(basename "${right_coord}")
fi

if [ "${view_image}" == 'yes' 2>/dev/null ] && [ -f "${out_image}" ] && [ "${create_comp}" == 'yes' 2>/dev/null ]; then
	"${cmd_caret_command}" -image-view "${out_image}"
fi

exit_message 0