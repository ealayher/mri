#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 05/21/2014 By: Evan Layher (1.0) (layher@psych.ucsb.edu)
# Revised: 04/29/2017 By: Evan Layher (2.0) Mac and Linux compatible + minor updates
# Revised: 01/19/2018 By: Evan Layher (2.1) Specify all inputs/options from commandline
# Adapted from Michael Harm's: get_movement.csh and get_FWHM.csh scripts
#--------------------------------------------------------------------------------------#
# FSL output quality control (qc) parameters in CSV file for each lower-level FEAT folder
# Mean absolute/relative motion, full width at half maximum (FWHM), and signal-to-fluctuation noise ratios (SFNR)

## --- LICENSE INFORMATION --- ##
## motion_qc_fsl.sh is the proprietary property of The Regents of the University of California ("The Regents.")

## Copyright © 2014-18 The Regents of the University of California, Davis campus. All Rights Reserved.

## Redistribution and use in source and binary forms, with or without modification, are permitted by nonprofit, 
## research institutions for research use only, provided that the following conditions are met:

## • Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer
## • Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
##	in the documentation and/or other materials provided with the distribution. 
## • The name of The Regents may not be used to endorse or promote products derived from this software without specific prior written permission.

## The end-user understands that the program was developed for research purposes and is advised not to rely exclusively on the program for any reason.

## THE SOFTWARE PROVIDED IS ON AN "AS IS" BASIS, AND THE REGENTS HAVE NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
## THE REGENTS SPECIFICALLY DISCLAIM ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, 
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
## IN NO EVENT SHALL THE REGENTS BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES, 
## INCLUDING BUT NOT LIMITED TO  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, LOSS OF USE, DATA OR PROFITS, OR BUSINESS INTERRUPTION, 
## HOWEVER CAUSED AND UNDER ANY THEORY OF LIABILITY WHETHER IN CONTRACT, STRICT LIABILITY OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## If you do not agree to these terms, do not download or use the software.  
## This license may be modified only in a writing signed by authorized signatory of both parties.

## For commercial license information please contact copyright@ucdavis.edu.
## --------------------------- ##

#-------------------------------- VARIABLES --------------------------------#
def_outfile='motion_qc.csv' # Default output file

# Output labels
abs_label='abs'   # Output header for absolute motion
rel_label='rel'   # Output header for relative motion
fwhm_label='fwhm' # Output header for full width at half maximum
sfnr_label='sfnr' # Output header for signal-to-fluctuation noise ratios
label_spacing='_' # Delimiter that separate output label headers (if necessary)
scan_label='sub'  # Header for scan output
missing_value='.' # Output for missing values

def_col_order=("${abs_label}" "${rel_label}" "${fwhm_label}" "${sfnr_label}")

# FSL files containing mean motion values and FWHM information
abs_motion_file='mc/prefiltered_func_data_mcf_abs_mean.rms'
rel_motion_file='mc/prefiltered_func_data_mcf_rel_mean.rms'
brain_mask='mask.nii.gz'
smoothness_file='stats/smoothness'

# FSL get values for FWHM calculations
mask_dim1='pixdim1' # fslhd ${brain_mask} dimension 1
mask_dim2='pixdim2' # fslhd ${brain_mask} dimension 2
mask_dim3='pixdim3' # fslhd ${brain_mask} dimension 3
mask_delimiter=' '  # fslhd delimiter
smooth_value='RESELS' # Line containing resels in ${smoothness_file}
smooth_delimiter=' '  # ${smoothness_file} delimiter

# SFNR files
p_map='avg152T1_gray_Pmap.nii.gz' # Standard brain dimensions
out_sfnr_text='sfnr_wavg.txt' # Saved within each FEAT folder
out_sfnr_nifti='sfnr.nii.gz'
out_sfnr_reg='sfnr_std_lin.nii.gz'
out_sfnr_product='sfnr_gm_product.nii.gz'
out_sfnr_mask='sfnr_gm_product_mask.nii.gz'

# SFNR linear registration input values
func2stan='reg/example_func2standard.mat'
sub_stan='reg/standard.nii.gz'
sub_mean_func='mean_func.nii.gz'
sub_square='stats/sigmasquareds.nii.gz'

feat_ext='.feat'   # FSL lower-level FEAT folder extension
gfeat_ext='.gfeat' # FSL higher-level FEAT folder extension
nii_ext='.nii.gz'  # NIFTI file extension

# FSL commands
cmd_flirt="${FSLDIR}/bin/flirt" # Linear registration (SFNR)
cmd_fslhd="${FSLDIR}/bin/fslhd" # Read NIFTI header (FWHM)
cmd_fslmaths="${FSLDIR}/bin/fslmaths" # NIFTI math operations (SFNR)
cmd_fslstats="${FSLDIR}/bin/fslstats" # NIFTI stat operations (SFNR)

temp_placeholder='XXX-TEMP-XXX' # Place for missing FEAT value in 'final_feats'
verify_time='10' # (secs) Display settings before running (input -s to suppress)
#--------------------------- DEFAULT SETTINGS ------------------------------#
max_bg_jobs='5' # Maximum background processes (1-10)
text_editors=('kwrite' 'kate' 'gedit' 'open -a /Applications/BBEdit.app' 'open') # GUI text editor commands in preference order

IFS_old="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (useful when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
usage () { # Help message: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: ${gre}FSL ${whi}output lower-level ${ora}FEAT ${whi}quality control parameters to CSV file
 ${pur}[${ora}1${pur}] ${ora}Absolute motion${whi}: mean absolute motion per scan
 ${pur}[${ora}2${pur}] ${ora}Relative motion${whi}: mean relative motion per scan
 ${pur}[${ora}3${pur}] ${ora}Full width at half maximum${whi}: mean FWHM per scan
 ${pur}[${ora}4${pur}] ${ora}Signal-to-fluctuation noise ratios${whi}: mean SFNR per scan
 
 ${gre}Absolute motion ${ora}FEAT ${gre}file: ${ora}${abs_motion_file}${whi}
 ${gre}Relative motion ${ora}FEAT ${gre}file: ${ora}${rel_motion_file}${whi}
 ${gre}FWHM${whi}:
  ${ora}A: ${whi}Convert ${gre}FSL ${whi}RESEL dimensions from 1 voxel to cubic mm
  ${ora}B: ${whi}Cube root to obtain geometric mean
 ${gre}SFNR${whi}: 
  ${ora}A: ${whi}Register to standard brain ${ora}(${red}dimensions must match${ora})${whi}
  ${ora}B: ${whi}Multiply by p-map ${ora}(${gre}${p_map}${ora})${whi}
  ${ora}C: ${whi}Create binary brain mask
  ${ora}D: ${whi}Calculate weighted SFNR average
     
${ora}ADVICE${whi}: Create alias in ${ora}${HOME}/.bashrc${whi}
${ora}(${whi}e.g. ${gre}alias qc='${script_path}'${ora})${whi}
     
${ora}USAGE${whi}: Input lower-level ${ora}FEAT ${whi}folders ${ora}(${whi}or text file of ${ora}FEAT ${whi}folders${ora})${whi}
 [${ora}1${whi}] ${gre}qc ${ora}f1.feat f2.feat${whi}
 [${ora}2${whi}] ${gre}qc ${ora}feat_file.txt${whi} # Text file listing ${ora}FEAT ${whi}folders
 [${ora}3${whi}] ${gre}qc ${ora}~/all_feats${whi} # Folder containing ${ora}FEAT ${whi}folders
       
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-abs${ora} Absolute motion${whi}: specify column order and values to include
 [${ora}4${whi}] ${gre}qc ${ora}feat_file.txt ${pur}-abs -fwhm -rel -sfnr${whi}
 ${pur}-c${whi}   Specify portion of ${ora}FEAT ${whi}folder path that designates a column
 [${ora}5${whi}] ${gre}qc ${ora}f4.feat f2.feat ${pur}-c ${ora}f1 f2 f3 f4${whi}
 ${pur}-cc${whi}  Chunk column values together ${ora}(${whi}e.g. abs1,abs2,abs3,rel1,rel2,rel3${ora})${whi}
 ${pur}-cl${whi}  Column labels ${ora}(${whi}if ${pur}-c ${whi}input not desired${ora})${whi}
 [${ora}6${whi}] ${gre}qc ${ora}f4.feat f2.feat ${pur}-c ${ora}f1 f2 f3 f4 ${pur}-cl ${ora}in1 in2 in3 in4${whi} 
 ${pur}-cs${whi}  Prevent clearing screen at start
 ${pur}-f${whi}   Overwrite output file
 ${pur}-ff${whi}  Overwrite SFNR files
 ${pur}-fp${whi}  Include full ${ora}FEAT ${whi}path for row labels ${ora}(${whi}auto-truncates otherwise${ora})${whi}
 ${pur}-fwhm${ora} FWHM${whi}: specify column order and values to include
 [${ora}7${whi}] ${gre}qc ${ora}feat_file.txt ${pur}-fwhm -sfnr${whi}
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-out${whi} or ${pur}-output${whi} Specify output folder or file
 ${pur}-p${whi}   Specify p-map file path ${ora}(${gre}${p_map}${ora})${whi}
 ${pur}-r${whi}   Specify portion of ${ora}FEAT ${whi}folder path that designates a row
 [${ora}8${whi}] ${gre}qc ${ora}f4.feat f2.feat ${pur}-r ${ora}f${whi}
 ${pur}-rel${ora} Relative motion${whi}: specify column order and values to include
 [${ora}9${whi}] ${gre}qc ${ora}feat_file.txt ${pur}-abs -rel${whi}
 ${pur}-rl${whi}  Row labels ${ora}(${whi}if ${pur}-r ${whi}input not desired${ora})${whi}
 [${ora}10${whi}] ${gre}qc ${ora}f4.feat f2.feat ${pur}-r ${ora}f ${pur}-rl ${ora}IN-FEAT${whi}
 ${pur}-s${whi}   Suppress confirmation message and immediately start process
 ${pur}-sfnr${ora} SFNR${whi}: specify column order and values to include
 [${ora}11${whi}] ${gre}qc ${ora}feat_file.txt ${pur}-sfnr -fwhm -abs -rel${whi}
 
${ora}DEFAULT SETTINGS${whi}:
column order:
$(display_values ${def_col_order[@]})
column style: ${ora}Interleaved${whi} ${ora}(${whi}e.g. abs1,rel1,fwhm1,sfnr1,abs2,rel2,fwhm2,sfnr2${ora})${whi}

output file: ${gre}${def_outfile}${whi}

p-map file: ${gre}${p_map}${whi}
 
${ora}VERSION: ${gre}${version}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm
} # usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version='2.1' # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
chunk_col='no'        # 'no' : Chunk columns together    [INPUT: '-cc']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
force_overwrite='no'  # 'no' : Overwrite output file     [INPUT: '-f']
force_sfnr_ow='no'    # 'no' : Overwrite SFNR files      [INPUT: '-ff']
full_path='no'        # 'no' : FEAT path in output file  [INPUT: '-fp']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')
suppress_msg='no'     # 'no' : Do NOT verify parameters  [INPUT: '-s']

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate user inputs
	if [ "${1}" == '-abs' 2>/dev/null ] || [ "${1}" == '-c' 2>/dev/null ] || \
	   [ "${1}" == '-cc' 2>/dev/null ] || [ "${1}" == '-cl' 2>/dev/null ] || \
	   [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-f' 2>/dev/null ] || \
	   [ "${1}" == '-ff' 2>/dev/null ] || [ "${1}" == '-fp' 2>/dev/null ] || \
	   [ "${1}" == '-fwhm' 2>/dev/null ] || [ "${1}" == '-h' 2>/dev/null ] || \
	   [ "${1}" == '--help' 2>/dev/null ] || [ "${1}" == '-nc' 2>/dev/null ] || \
	   [ "${1}" == '-nm' 2>/dev/null ] || [ "${1}" == '-o' 2>/dev/null ] || \
	   [ "${1}" == '--open' 2>/dev/null ] || [ "${1}" == '-out' 2>/dev/null ] || \
	   [ "${1}" == '-output' 2>/dev/null ] || [ "${1}" == '-p' 2>/dev/null ] || \
	   [ "${1}" == '-r' 2>/dev/null ] || [ "${1}" == '-rel' 2>/dev/null ] || \
	   [ "${1}" == '-rl' 2>/dev/null ] || [ "${1}" == '-s' 2>/dev/null ] || \
	   [ "${1}" == '-sfnr' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ "${c_in}" == 'yes' 2>/dev/null ]; then
		c_vals+=("${1}") # Column file search values
	elif [ "${cl_in}" == 'yes' 2>/dev/null ]; then
		c_labels+=("${1}") # Column label values
	elif [ "${o_in}" == 'yes' 2>/dev/null ]; then
		outfile="${1}" # Output file or folder
		o_in='no' # Only get 1 output file
	elif [ "${p_in}" == 'yes' 2>/dev/null ]; then
		check_nii=$(echo "${1}" |grep "${nii_ext}$")
		if ! [ -z "${check_nii}" ] && [ -f "${1}" ]; then	
			pmap_file=$(mac_readlink "${1}") # p-map file
		else
			bad_inputs+=("INVALID-P-MAP-FILE:${1}")
		fi
		
		p_in='no' # Only get 1 p-map file
	elif [ "${r_in}" == 'yes' 2>/dev/null ]; then
		r_vals+=("${1}") # Row file search values
	elif [ "${rl_in}" == 'yes' 2>/dev/null ]; then
		r_labels+=("${1}") # Row label values
	elif [ "${1:0:1}" == '-' 2>/dev/null ]; then
		bad_inputs+=("INVALID-OPTION:${1}")
	elif [ -d "${1}" ]; then
		check_feat "${1}" # Check FEAT folder
	elif [ -f "${1}" ]; then
		file_dirs=($(cat "${1}" 2>/dev/null)) # Use 'cat' to avoid non-textfile errors
		for i in ${!file_dirs[@]}; do
			file_dir="${file_dirs[${i}]}"
			if [ -d "${file_dir}" ]; then
				check_feat "${file_dir}" # Check FEAT folder
			else
				bad_inputs+=("INPUT-FILE-MUST-ONLY-INCLUDE-FOLDERS:${file_dir}:${1}")
			fi
		done # for i in ${!in_dirs[@]}
	else # Invalid input
		bad_inputs+=("INVALID-INPUT:${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	# Reset read-in values
	c_in='no'  # Column search values
	cl_in='no' # Column label values
	o_in='no'  # Read output file
	p_in='no'  # Read input p-map file
	r_in='no'  # Row search values
	rl_in='no' # Row label values
	
	if [ "${1}" == '-abs' ]; then
		col_order+=("${abs_label}")  # Append absolute motion to column order
	elif [ "${1}" == '-c' ]; then
		c_in='yes'                   # Read in column values
	elif [ "${1}" == '-cc' ]; then
		chunk_col='yes'              # Chunk column values (instead of interleaved)
	elif [ "${1}" == '-cl' ]; then
		cl_in='yes'                  # Read in column label values	
	elif [ "${1}" == '-cs' ]; then
		clear_screen='no'            # Do NOT clear screen at start
	elif [ "${1}" == '-f' ]; then
		force_overwrite='yes'        # Overwrite files
	elif [ "${1}" == '-ff' ]; then
		force_sfnr_ow='yes'         # Overwrite SFNR files
	elif [ "${1}" == '-fp' ]; then
		full_path='yes'              # Use FEAT folder path as row labels
	elif [ "${1}" == '-fwhm' ]; then
		col_order+=("${fwhm_label}") # Append fwhm to column order
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'          # Display help message
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no'         # Do NOT display messages in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'            # Do NOT display exit message
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'            # Open this script
	elif [ "${1}" == '-out' ] || [ "${1}" == '-output' ]; then
		o_in='yes'                   # Read in output folder/file
	elif [ "${1}" == '-p' ]; then
		p_in='yes'                   # Read in p-map file
	elif [ "${1}" == '-r' ]; then
		r_in='yes'                   # Read in row values
	elif [ "${1}" == '-rel' ]; then
		col_order+=("${rel_label}")  # Append relative motion to column order
	elif [ "${1}" == '-rl' ]; then
		rl_in='yes'                  # Read in row label values
	elif [ "${1}" == '-s' ]; then
		suppress_msg='yes'           # Do NOT display parameter verification message at start
	elif [ "${1}" == '-sfnr' ]; then
		col_order+=("${sfnr_label}") # Append SFNR to column order
	else # if option is undefined (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

assign_final_feat () { # Create final_feats array (final FEAT output order)
	row_grep1="${1}" # Row value to grep
	row_grep2="${2}" # Row value to grep (column input)
	
	if [ -z "${row_grep2}" ]; then
		row_grep2="${row_grep1}" # Use same value
	fi
	
	chk_feat=($(printf "%s${IFS}" ${in_feats[@]} |grep "${row_grep1}" |grep "${row_grep2}"))
	if [ "${#chk_feat[@]}" -eq '0' ]; then
		final_feats+=("${temp_placeholder}") # Blank value
	elif [ "${#chk_feat[@]}" -eq '1' ]; then
		final_feats+=("${chk_feat[0]}") # FEAT path
	else # Script error (for debugging)
		bad_inputs+=("MULTIPLE-FEATS-FOR-ROW:${row_grep1},${#chk_feat[@]}")
	fi
} # assign_final_feat

check_bad_inputs () { # Crash if 'bad_inputs' array not empty
	if [ "${#bad_inputs[@]}" -gt '0' ]; then
		clear
		echo "${red}INVALID INPUT:${whi}"
		display_values ${bad_inputs[@]}
		exit_message 99
	fi
} # check_bad_inputs

check_duplicates () { # Crash if duplicate inputs found (first input is message details)
	msg_val="${1}" # Display message type
	input_vals=($(printf "%s${IFS}" ${@} |grep -v "^${msg_val}$" |sort)) # Alphabetize values
	chk_dup_vals=($(printf "%s${IFS}" ${input_vals[@]} |sort -u)) # Remove duplicate values
	
	if [ "${#chk_dup_vals[@]}" -ne "${#input_vals[@]}" ]; then # Duplicate files found
		dup_count=$((${#input_vals[@]} - ${#chk_dup_vals[@]})) # Total non-unique folders
		echo "${pur}DISPLAYING ALL ${ora}${msg_val} ${pur}INPUTS IN ALPHABETICAL ORDER:${whi}"
		display_values ${input_vals[@]}
		echo "${red}TOTAL DUPLICATE ${ora}${msg_val} ${red}INPUTS FOUND (${ora}${dup_count}${red}/${ora}${#input_vals[@]}${red})${whi}"
		exit_message 98
	fi
} # check_duplicates

check_feat () { # Check for lower-level FEAT folder or search non-FEAT folder
	g_check=$(echo "${1}" |grep "${gfeat_ext}$") # Exclude GFEAT folders
	if ! [ -z "${g_check}" ]; then # Higher-level GFEAT
		bad_inputs+=("LOWER-LEVEL-FEAT-ONLY:${1}")
	else # Lower-level FEAT or non-FEAT folder
		f_check=$(echo "${1}" |grep "${feat_ext}$") # Check FEAT folder
		in_dir=$(mac_readlink "${1}") # Full path of input folder
		if [ -z "${check_feat}" ]; then # Search for FEAT folders
			in_feats+=($(find "${in_dir}" -maxdepth 1 -type d -name "*${feat_ext}")) # Folders
			in_feats+=($(find "${in_dir}" -maxdepth 1 -type l -name "*${feat_ext}")) # Links
		else # Lower-level FEAT
			in_feats+=("${in_dir}")
		fi
	fi # if ! [ -z "${g_check}" ]
} # check_feat

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

control_bg_jobs () { # Controls number of background processes
	if [ "${max_bg_jobs}" -eq '1' 2>/dev/null ]; then
		wait # Proceed after all background processes are finished
	else
		if [ "${max_bg_jobs}" -gt '1' 2>/dev/null ] && [ "${max_bg_jobs}" -le '10' 2>/dev/null ]; then 
			true # Make sure variable is defined and valid number
		elif [ "${max_bg_jobs}" -gt '10' 2>/dev/null ]; then
			echo "${red}RESTRICTING BACKGROUND PROCESSES TO 10${whi}"
			max_bg_jobs='10' # Background jobs should not exceed '10' (Lowers risk of crashing)
		else # If 'max_bg_jobs' not defined as integer
			echo "${red}INVALID VALUE: ${ora}max_bg_jobs='${gre}${max_bg_jobs}${ora}'${whi}"
			max_bg_jobs='1'
		fi
	
		job_count=($(jobs -p)) # Place job IDs into array
		if ! [ "$?" -eq '0' ]; then # If 'jobs -p' command fails
			echo "${red}ERROR (${ora}control_bg_jobs${red}): ${ora}RESTRICTING BACKGROUND PROCESSES${whi}"
			max_bg_jobs='1'
			wait
		else
			if [ "${#job_count[@]}" -ge "${max_bg_jobs}" ]; then
				sleep 0.2 # Wait 0.2 seconds to prevent overflow errors
				control_bg_jobs # Check job count
			fi
		fi # if ! [ "$?" -eq '0' ]
	fi # if [ "${max_bg_jobs}" -eq '1' 2>/dev/null ]
} # control_bg_jobs

create_sfnr () { # Compute SFNR for FEAT FOLDER
	cd "${in_feat}" # Change directory to avoid paths with special characters
	base_pmap=$(basename "${local_pmap}") # pmap copied into FEAT folder

	# Create SFNR volume using mean image and sigmasquared
	"${FSLDIR}/bin/fslmaths" "${sub_mean_func%*.nii*}" -mul "${sub_mean_func%*.nii*}" -div "${sub_square%*.nii*}" -sqrt "${out_sfnr_nifti%*.nii*}"

	if [ -f "${out_sfnr_nifti}" ]; then # linear registration
		"${FSLDIR}/bin/flirt" -in "${out_sfnr_nifti%*.nii*}" -ref "${sub_stan%*.nii*}" -init "${func2stan}" -applyxfm -out "${out_sfnr_reg%*.nii*}"

		if [ -f "${out_sfnr_reg}" ]; then # Create weighted values
			"${FSLDIR}/bin/fslmaths" "${out_sfnr_reg%*.nii*}" -mul "${base_pmap%*.nii*}" "${out_sfnr_product%*.nii*}"

			if [ -f "${out_sfnr_product}" ]; then # Create output text file
				"${FSLDIR}/bin/fslmaths" "${out_sfnr_product%*.nii*}" -bin "${out_sfnr_mask%*.nii*}" # Create mask
				mean_sfnr=$("${FSLDIR}/bin/fslstats" "${out_sfnr_product%*.nii*}" -k "${out_sfnr_mask%*.nii*}" -M |awk '{print $1}') # Remove trailing white space
				mean_pmap=$("${FSLDIR}/bin/fslstats" "${base_pmap%*.nii*}" -k "${out_sfnr_mask%*.nii*}" -M |awk '{print $1}') # Remove trailing white space
				final_value=$(echo |awk -v var1="${mean_sfnr}" -v var2="${mean_pmap}" '{print var1/var2}')
				echo "${final_value}" > "${out_sfnr_text}"
			fi # if [ -f "${out_sfnr_product}" ]
		fi # if [ -f "${out_sfnr_reg}" ]
	fi # if [ -f "${out_sfnr_nifti}" ]
	
	if [ -f "${out_sfnr_text}" ]; then
		echo "${gre}CREATED: ${ora}${output_sfnr}${whi}"
	else
		echo "${red}NOT CREATED: ${ora}${output_sfnr}${whi}"
	fi
} # create_sfnr

display_values () { # Display output with numbers
	if [ "${#@}" -gt '0' ]; then
		val_count=($(seq 1 1 ${#@}))
		vals_and_count=($(paste -d "${IFS}" <(printf "%s${IFS}" ${val_count[@]}) <(printf "%s${IFS}" ${@})))
		printf "${pur}[${ora}%s${pur}] ${gre}%s${IFS}${whi}" ${vals_and_count[@]}
	fi
} # display_values

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
			exit_message 97 -nh -nm
		fi
	else # Missing input file
		echo "${red}MISSING FILE: ${ora}${open_file}${whi}"
	fi # if [ -f "${open_file}" ]; then
} # open_text_editor

row_file () { # Get row value from file (abs/rel motion, SFNR)
	in_file="${1}" # Input file with desired value

	if ! [ -f "${in_file}" ]; then # Placeholder FEAT value or missing file
		row_output+=("${missing_value}") # Missing value
	else # Get value
		row_output+=($(<"${in_file}"))
	fi
} # row_file

row_fwhm () { # Computer FWHM value
	feat_dir="${1}"
	mask_file="${feat_dir}/${brain_mask}"
	smooth_file="${feat_dir}/${smoothness_file}"
	
	if ! [ -d "${feat_dir}" ]; then # Placeholder FEAT value or missing file
		row_output+=("${missing_value}") # Missing value
	elif [ -f "${mask_file}" ] && [ -f "${smooth_file}" ]; then
		mask_dims=($("${FSLDIR}/bin/fslhd" "${mask_file}" |grep -E "${mask_dim1}|${mask_dim2}|${mask_dim3}" |awk -F "${mask_delimiter}" '{print $2}')) # mask dimensions
		resels=$(grep "${smooth_value}" "${smooth_file}" |awk -F "${smooth_delimiter}" '{print $2}')
			
		if ! [ -z "${mask_dims[0]}" ] && ! [ -z "${mask_dims[1]}" ] && \
		   ! [ -z "${mask_dims[2]}" ] && ! [ -z "${resels}" ]; then
			# multiply 3 mask dimensions (mm) by RESELS and cube root
			check_calc=$(eval "echo |awk '{print ($(echo ${mask_dims[0]} ${mask_dims[1]} ${mask_dims[2]} ${resels} |sed 's@ @*@g'))^(1/3)}'")
			if [ -z "${check_calc}" ]; then
				echo "${red}CALCULATION ERROR: ${ora}${feat_dir}${whi}"
				row_output+=("${missing_value}")
			else
				row_output+=("${check_calc}")
			fi
		else # Missing value(s)
			echo "${red}MISSING VALUE(S): ${gre}${feat_dir} ${ora}[1] ${mask_dims[0]} [2] ${mask_dims[1]} [3] ${mask_dims[2]} [4] ${resels}${whi}"
			row_output+=("${missing_value}")
		fi
	else # Missing file(s)
		echo "${red}MISSING AT LEAST ONE FILE:${whi}"
		display_values "${mask_file}" "${smooth_file}"
		row_output+=("${missing_value}")
	fi # if [ -f "${mask_file}" ] && [ -f "${smooth_file}" ]
} # row_fwhm

vital_file () { # Exit script if missing file
	for vitals; do
		if ! [ -e "${vitals}" 2>/dev/null ]; then
			bad_files+=("${vitals}")
		fi
	done
	
	if [ "${#bad_files[@]}" -gt '0' ]; then
		echo "${red}MISSING ESSENTIAL FILE(S):${whi}"
		display_values ${bad_files[@]}
		exit_message 96 -nh -nm
	fi
} # vital_file

#-------------------------------- MESSAGES ---------------------------------#
control_c () { # Function activates after 'ctrl + c'
	echo "${red}FINISHING CURRENT BACKGROUND PROCESSES BEFORE CRASHING${whi}"
	exit_message 95 -nh
} # control_c

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
	
	printf "${formatreset}\n"
	IFS="${IFS_old}" # Reset IFS
	exit "${exit_type}"
} # exit_message

#---------------------------------- CODE -----------------------------------#
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

echo 'READING INPUT VALUES: '$(basename "${script_path}") # Alert user of script start
for inputs; do # Read through all inputs
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
	exit_message 0 -nm
else # Exit script if invalid inputs
	check_bad_inputs
fi

if [ "${#in_feats[@]}" -eq '0' ]; then # No input FEAT folders found
	echo "${red}MUST SPECIFY INPUT FEAT FOLDERS${whi}"
	exit_message 1
fi

if [ -z "${missing_value}" ] || [ "${missing_value}" == ',' ]; then
	missing_value='.' # Prevent CSV file errors
fi

if [ -z "${outfile}" ]; then # Output file not specified
	outfile="${def_outfile}" # Use default file
else # Output file/folder specified
	if [ -d "${outfile}" ]; then # Use default filename
		outfile="${outfile}/${def_outfile}" # Default filename plus output folder
	else # File input must have existing output folder
		outdir=$(dirname $(mac_readlink "${outfile}"))
		if ! [ -d "${outdir}" ]; then
			echo "${red}OUTPUT FOLDER NOT FOUND: ${ora}${outfile}${whi}"
			exit_message 2
		fi
	fi # if [ -d "${outfile}" ]
fi # if [ -z "${outfile}" ]

if [ -f "${outfile}" ] && ! [ "${force_overwrite}" == 'yes' 2>/dev/null ]; then
	echo "${red}OUTPUT FILE EXISTS (${ora}use ${pur}-f ${ora}option to overwrite${red}): ${ora}${outfile}${whi}"
	exit_message 3
fi

if [ "${#col_order[@]}" -eq '0' ]; then # Use default order
	col_order=($(printf "%s${IFS}" ${def_col_order[@]})) # Use printf to avoid $IFS errors
fi

if [ "${#c_labels[@]}" -gt '0' ] && [ "${#c_labels[@]}" -ne "${#c_vals[@]}" ]; then
	echo "${red}COLUMN LABEL (${pur}-cl${red}) INPUTS (${ora}${#c_labels[@]}${red}) MUST MATCH COLUMN VALUE (${pur}-c${red}) INPUTS (${ora}${#c_vals[@]}${red})${whi}"
	exit_message 4
fi

if [ "${#r_labels[@]}" -gt '0' ] && [ "${#r_labels[@]}" -ne "${#r_vals[@]}" ]; then
	echo "${red}ROW LABEL (${pur}-rl${red}) INPUTS (${ora}${#r_labels[@]}${red}) MUST MATCH ROW VALUE (${pur}-r${red}) INPUTS (${ora}${#r_vals[@]}${red})${whi}"
	exit_message 5
fi

check_fwhm=$(printf "%s${IFS}" ${col_order[@]} |grep "${fwhm_label}")
if ! [ -z "${check_fwhm}" ]; then
	vital_file "${cmd_fslhd}"
fi # Exit script if missing 'fslhd' command

check_sfnr=$(printf "%s${IFS}" ${col_order[@]} |grep "${sfnr_label}")
if ! [ -z "${check_sfnr}" ]; then
	vital_file "${cmd_flirt}" "${cmd_fslmaths}" "${cmd_fslstats}"
	
	if [ -z "${pmap_file}" ]; then
		pmap_file="${p_map}" # Use default file
	fi
	
	vital_file "${pmap_file}"
fi # Exit script if missing FSL commands or p-map file

check_duplicates 'FEAT FOLDER' ${in_feats[@]} # Check for duplicate FEAT folder inputs
check_duplicates 'COLUMN VALUES' ${c_vals[@]} # Check for duplicate (-c) inputs
if [ "${#c_vals[@]}" -gt '1' ]; then # Multiple columns
	tot_c="${#c_vals[@]}" # Total column values
	if [ "${#c_labels[@]}" -eq '0' ]; then # c_vals become c_labels
		c_labels=($(printf "%s${IFS}" ${c_vals[@]}))
	else # Check for duplicate labels
		check_duplicates 'COLUMN LABELS' ${c_labels[@]} # Check for duplicate (-cl) inputs
	fi
	
	for i in ${!c_vals[@]}; do # Each FEAT folder must have unique column value
		c_val="${c_vals[${i}]}"
		chk_col_feat+=($(printf "%s${IFS}" ${in_feats[@]} |grep -E -n "${c_val}")) # Grep with number
	done
	
	for i in ${!in_feats[@]}; do # Check each FEAT folder has exactly 1 column assignment
		in_feat="${in_feats[${i}]}"
		adj_i=$((${i} + 1)) # Add 1 to match with grep number
		chk_unique=($(printf "%s${IFS}" ${chk_col_feat[@]} |grep "^${adj_i}:"))
		if [ "${#chk_unique[@]}" -eq '0' ]; then # Must be assigned to 1 column
			bad_inputs+=("FEAT-NOT-ASSIGNED-TO-COLUMN_-c:${in_feat}")
		elif [ "${#chk_unique[@]}" -gt '1' ]; then # Must be assigned to 1 column only
			bad_inputs+=("FEAT-ASSIGNED-TO-${#chk_unique[@]}-COLUMNS_-c:${in_feat}")
		fi
	done
else # 1 column only
	tot_c='1' # Total column values
fi # if [ "${#c_vals[@]}" -gt '1' ]

if [ "${#r_vals[@]}" -gt '0' ]; then # Specified rows
	check_duplicates 'ROW VALUES' ${r_vals[@]} # Check for duplicate (-r) inputs
	
	if [ "${#r_labels[@]}" -eq '0' ]; then
		r_labels=($(printf "%s${IFS}" ${r_vals[@]}))
	else
		check_duplicates 'ROW LABELS' ${r_labels[@]} # Check for duplicate (-rl) inputs
	fi
	
	for i in ${!r_vals[@]}; do # Each FEAT folder must have a row assignment
		r_val="${r_vals[${i}]}"
		chk_row_feat+=($(printf "%s${IFS}" ${in_feats[@]} |grep -E -n "${r_val}")) # Grep with number
	done
	
	for i in ${!in_feats[@]}; do # Check each FEAT folder has a row assignment
		in_feat="${in_feats[${i}]}"
		adj_i=$((${i} + 1)) # Add 1 to match with grep number
		chk_row=($(printf "%s${IFS}" ${chk_row_feat[@]} |grep "^${adj_i}:"))
		if [ "${#chk_row[@]}" -eq '0' ]; then # Must be assigned to least 1 row
			bad_inputs+=("FEAT-NOT-ASSIGNED-TO-ROW_-r:${in_feat}")
		elif [ "${#chk_row[@]}" -gt "${tot_c}" ]; then # Cannot exceed column numbers
			bad_inputs+=("FEAT-ASSIGNED-TO-${#chk_row[@]}/${tot_c}-ROWS_-r:${in_feat}")
		fi
	done # for i in ${!in_feats[@]}
else # Use full path or unique folder name
	r_vals=($(printf "%s${IFS}" ${in_feats[@]})) # Full paths
	r_labels=($(printf "%s${IFS}" ${in_feats[@]})) # Full paths
	
	if [ "${tot_c}" -gt '1' ]; then # Try to predict rows with columns
		for i in ${!c_vals[@]}; do # Loop thru column values
			c_val="${c_vals[${i}]}"
			r_vals=($(printf "%s${IFS}" ${r_vals[@]} |sed "s@${c_val}@${temp_placeholder}@g")) # Placeholder
			r_labels=($(printf "%s${IFS}" ${r_labels[@]} |sed "s@${c_val}@@g")) # Remove ${c_val}
		done
	fi # if [ "${tot_c}" -gt '1' ]
	
	r_vals=($(printf "%s${IFS}" ${r_vals[@]} |awk '!r_vals[$0]++')) # Unique values only
	r_labels=($(printf "%s${IFS}" ${r_labels[@]} |awk '!r_labels[$0]++')) # Unique values only

	if ! [ "${full_path}" == 'yes' 2>/dev/null ]; then # Truncate if possible
		dir_check=($(printf "%s${IFS}" ${in_feats[@]}))
		until [ "${#dir_check[@]}" -eq '0' ]; do # Loop thru directories to find unique folder name
			base_check=($(basename ${dir_check[@]})) # Folder basenames
			base_check_unique=($(printf "%s${IFS}" ${base_check[@]} |awk '!base_check[$0]++')) # Unique basenames
			dir_check=($(printf "%s${IFS}" ${dir_check[@]%/*} |sed "s, /,\\${IFS}/,g")) # Directory names (work around with $IFS)
			if [ "${#base_check_unique[@]}" -eq "${#r_vals[@]}" ]; then # Use unique folder as labels
				r_labels=($(printf "%s${IFS}" ${base_check_unique[@]} |sed "s,${feat_ext}$,,g")) # Remove FEAT extension
				break # Break out of loop
			fi
		done # until [ "${#dir_check[@]}" -eq '0' ]
	fi
	
	check_duplicates 'ROW VALUES' ${r_vals[@]} # Check for duplicate (-r) inputs
	check_duplicates 'ROW LABELS' ${r_labels[@]} # Check for duplicate (-rl) inputs
fi # if [ "${#r_vals[@]}" -gt '0' ]

check_bad_inputs # Crash script if 'bad_inputs' array not empty

for i in ${!r_vals[@]}; do
	r_val="${r_vals[${i}]}"
	if [ "${tot_c}" -gt '1' ]; then
		for j in ${!c_vals[@]}; do
			c_val="${c_vals[${j}]}" # Put into placeholder (if placeholder exists)
			temp_r_val=$(echo "${r_val}" |sed "s@${temp_placeholder}@${c_val}@g")
			assign_final_feat "${temp_r_val}" "${c_val}" # FEAT folder, placeholder, or invalid folder
		done
	else # 1 column only
		assign_final_feat "${r_val}" # FEAT folder, placeholder, or invalid folder
	fi
done # for i in ${!r_vals[@]}

tot_miss_vals=($(printf "%s${IFS}" ${final_feats[@]} |grep "${temp_placeholder}"))
check_bad_inputs # Crash script if 'bad_inputs' array not empty

# Alert user of parameters before running (-s to suppress)
if ! [ "${suppress_msg}" == 'yes' 2>/dev/null ]; then
	if ! [ "${verify_time}" -ge '1' 2>/dev/null ]; then
		verify_time='1' # Default to '1' to avoid errors
	fi
	
	echo "${pur}----- ${ora}${#in_feats[@]} ${gre}FEAT FOLDERS ${pur}-----${whi}" 
	display_values ${in_feats[@]}
	echo "${pur}----- ${ora}${#in_feats[@]} ${gre}FEAT FOLDERS ${pur}-----${whi}" 
	
	echo "${pur}----- ${ora}${#r_labels[@]} ${gre}ROWS ${pur}-----${whi}"
	display_values ${r_labels[@]}
	echo "${pur}----- ${ora}${#r_labels[@]} ${gre}ROWS ${pur}-----${whi}"
	
	if [ "${#c_labels[@]}" -gt '1' ]; then
		echo "${pur}----- ${ora}${#c_labels[@]} ${gre}COLUMNS ${pur}-----${whi}"
		display_values ${c_labels[@]}
		echo "${pur}----- ${ora}${#c_labels[@]} ${gre}COLUMNS ${pur}-----${whi}"
	fi
	
	echo "${ora}COLUMN ORDER${whi}"
	display_values ${col_order[@]}
	
	echo "${pur}--------------------${whi}"
	echo "${whi}FEAT FOLDERS  : ${gre}${#in_feats[@]}${whi}"
	echo "${whi}OUTPUT ROWS   : ${gre}${#r_labels[@]}${whi}"
	echo "${whi}OUTPUT COLUMNS: ${gre}${tot_c}${whi}"
	echo "${whi}MISSING VALUES: ${gre}${#tot_miss_vals[@]}${ora}/${gre}${#final_feats[@]}${whi}"
	echo "${whi}OUTPUT FILE   : ${gre}${outfile}${whi}"
	echo "${pur}--------------------${whi}"
	
	echo "${ora}INPUT ${gre}ctrl${ora}+${gre}c ${ora}TO CRASH${whi}"
	printf "${ora}STARTING IN: ${whi}"
	for i in $(seq "${verify_time}" -1 1); do # Loop thru seconds
		printf "${pur}${i} ${whi}" # Display number of seconds before processing
		sleep 1 # Wait 1 second
	done
fi # if ! [ "${suppress_msg}" == 'yes' 2>/dev/null ]

echo "${ora}PROCESSING (${gre}${#in_feats[@]}${ora}) FEAT FOLDERS${whi}" # Alert user of script start
if ! [ -z "${check_sfnr}" ]; then # Create text file with SFNR values
	echo "${ora}CALCULATING SIGNAL-FLUCTUATION-TO-NOISE (${gre}SFNR${ora}) VALUES${whi}"
	trap control_c SIGINT 2>/dev/null # Finishes background processes before crashing
	
	for i in ${!in_feats[@]}; do # Loop through FEAT folders
		in_feat="${in_feats[${i}]}"
		output_sfnr="${in_feat}/${out_sfnr_text}"

		if [ "${force_sfnr_ow}" == 'yes' 2>/dev/null ] || ! [ -f "${output_sfnr}" ]; then # Only create file if missing
			vital_file "${in_feat}/${func2stan}" "${in_feat}/${sub_stan}" "${in_feat}/${sub_mean_func}" "${in_feat}/${sub_square}"
			local_pmap="${in_feat}/"$(basename "${pmap_file}") # Local pmap

			cp "${pmap_file}" "${local_pmap}" # Copy pmap to FEAT folder
			vital_file "${local_pmap}"
			
			create_sfnr &
			control_bg_jobs
		fi
	done # for i in ${!in_feats[@]}
	
	wait # Finish background processes
fi # if [ "${sfnr}" == 'yes' 2>/dev/null ]

col_count='1' # Column count
row_idx='0'   # Row label index
for i in ${!final_feats[@]}; do
	final_feat="${final_feats[${i}]}"
	
	if [ "${i}" -eq '0' ]; then # Create file header (first row of output file)
		row_output=("${scan_label}") # Header for row labels
		
		if [ "${tot_c}" -le '1' ]; then # Standard labels
			for j in ${!col_order[@]}; do # Loop thru column labels
				row_output+=("${col_order[${j}]}") # Basic label headers
			done
		else
			if [ "${chunk_col}" == 'yes' 2>/dev/null ]; then
				for j in ${!col_order[@]}; do # Loop thru column order
					for k in ${!c_labels[@]}; do # Loop thru column labels
						row_output+=("${c_labels[${k}]}${label_spacing}${col_order[${j}]}") # Custom labels
					done # for k in ${!c_labels[@]}
				done # for j in ${!col_order[@]}
			else # Do not chunk column order (Reverse for-loop order)
				for j in ${!c_labels[@]}; do # Loop thru column labels
					for k in ${!col_order[@]}; do # Loop thru column order
						row_output+=("${c_labels[${j}]}${label_spacing}${col_order[${k}]}") # Custom labels
					done # for k in ${!c_labels[@]}
				done # for j in ${!col_order[@]}
			fi # if [ "${chunk_col}" == 'yes' 2>/dev/null ]
		fi # if [ "${tot_c}" -le '1' ]
		
		final_output=($(printf "%s," ${row_output[@]} |sed 's/,$//')) # Final header row
		row_output=() # Reset array
	fi # if [ "${i}" -eq '0' ]
	
	if [ "${col_count}" -eq '1' ]; then # Row label
		row_output=("${r_labels[${row_idx}]}")
		row_idx=$((${row_idx} + 1))
	fi

	for j in ${!col_order[@]}; do # Loop thru column order
		col_val="${col_order[${j}]}" 
		if [ "${tot_c}" -le '1' ] || [ "${chunk_col}" == 'no' 2>/dev/null ]; then # Sequential FEAT order
			if [ "${col_val}" == "${abs_label}" ]; then
				row_file "${final_feat}/${abs_motion_file}" # Get value from file
			elif [ "${col_val}" == "${fwhm_label}" ]; then
				row_fwhm "${final_feat}" # Calculate FWHM
			elif [ "${col_val}" == "${rel_label}" ]; then
				row_file "${final_feat}/${rel_motion_file}" # Get value from file
			elif [ "${col_val}" == "${sfnr_label}" ]; then
				row_file "${final_feat}/${out_sfnr_text}" # Get value from file
			fi # if [ "${col_val}" == "${abs_label}" ]
		else # Collect filenames for chunked columns 
			if [ "${col_val}" == "${abs_label}" ]; then
				abs_files+=("${final_feat}/${abs_motion_file}") # Absolute motion file
			elif [ "${col_val}" == "${fwhm_label}" ]; then
				fwhm_files+=("${final_feat}") # FEAT folder
			elif [ "${col_val}" == "${rel_label}" ]; then
				rel_files+=("${final_feat}/${rel_motion_file}") # Relative motion file
			elif [ "${col_val}" == "${sfnr_label}" ]; then
				sfnr_files+=("${final_feat}/${out_sfnr_text}") # SFNR file
			fi # if [ "${col_val}" == "${abs_label}" ]
		fi # if [ "${tot_c}" -le '1' ]
	done # for j in ${!col_order[@]}

	if [ "${col_count}" -eq "${tot_c}" ]; then # Save current row values, start new row
	
		if [ "${tot_c}" -gt '1' ] && [ "${chunk_col}" == 'yes' 2>/dev/null ]; then # Chunked columns
			for j in ${!col_order[@]}; do # Loop thru column labels
				col_val="${col_order[${j}]}"
				if [ "${col_val}" == "${abs_label}" ]; then
					for k in ${!abs_files[@]}; do
						row_file "${abs_files[${k}]}" # Get all absolute motion values
					done
				elif [ "${col_val}" == "${fwhm_label}" ]; then
					for k in ${!fwhm_files[@]}; do
						row_fwhm "${fwhm_files[${k}]}" # Compute FWHM values
					done
				elif [ "${col_val}" == "${rel_label}" ]; then
					for k in ${!rel_files[@]}; do
						row_file "${rel_files[${k}]}" # Get all relative motion values
					done
				elif [ "${col_val}" == "${sfnr_label}" ]; then
					for k in ${!sfnr_files[@]}; do
						row_file "${sfnr_files[${k}]}" # Get all SFNR values
					done
				fi # if [ "${col_val}" == "${abs_label}" ]
			done # for j in ${!col_order[@]}
			# Reset arrays
			abs_files=()
			fwhm_files=()
			rel_files=()
			sfnr_files=()
		fi # if [ "${tot_c}" -gt '1' ] && [ "${chunk_col}" == 'yes' 2>/dev/null ]
		
		col_count='1' # Reset count
		final_output+=($(printf "%s," ${row_output[@]} |sed 's/,$//')) # Save row values
		row_output=() # Reset array
	else # Increment column number
		col_count=$((${col_count} + 1))
	fi
done # for i in ${!final_feats[@]}

printf "%s${IFS}" ${final_output[@]} > "${outfile}" # Create motion/qc file

if [ "$?" -eq '0' ] && [ -f "${outfile}" ]; then
	echo "${gre}CREATED: ${ora}${outfile}${whi}"
else # Error with creating output file
	echo "${red}NOT CREATED: ${ora}${outfile}${whi}"
fi

exit_message 0