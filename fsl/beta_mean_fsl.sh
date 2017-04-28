#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 08/29/2013 By: Evan Layher (layher@psych.ucsb.edu)
# Revised: 09/20/2015 By: Evan Layher (1.1)
# Revised: 04/27/2017 By: Evan Layher (2.0) Linux and mac compatible + better versatility
#--------------------------------------------------------------------------------------#
# FSL output mean beta values (parameter estimates) into (g)feat directories
# MUST SOURCE fsl.sh script before running
# ASSUMES STANDARD FSL NAMING CONVENTION OF DIRECTORIES and FILES
# Run this script with '-h' option to read full help message

## --- LICENSE INFORMATION --- ##
## beta_mean_fsl.sh is the proprietary property of The Regents of the University of California ("The Regents.")

## Copyright © 2014-17 The Regents of the University of California, Davis campus. All Rights Reserved.

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
default_cope_files=() # () is all cope files; otherwise e.g. ('1' '4') for cope1.feat, cope4.feat
default_masks=()      # () is no folders/files; otherwise e.g. ('examplepath1/maskDir' 'examplepath2/maskDir')

wait_time='10' # Number of seconds to wait if "-f" option used

feat_extensions=('.feat' '.gfeat') # ('.feat' '.gfeat'): Only include FSL folders with these extensions
mask_extensions=('.nii.gz')        # ('.nii.gz'): Only include structural masks with these extensions
design_file='design.fsf'           # FSL design file in each cope.feat directory
feat_dir_code='feat_files'         # FSL keyword in design file to get inputs

output_beta_dir='betas'        # Folder that will contain mean beta output files in each .(g)feat folder
output_mask_edits='mask_edits' # Folder that will contain edited masks in ${output_beta_dir}
output_edit_name='_edit'       # Mask edit filename attached to mask file
output_header='beta_means'     # Header of output beta files
output_sub_header='inputs'     # Header of output FEAT column (if specified)
out_ext='.csv'                 # Output file extension
vxl_name='vxls'                # Output file voxel count identifier
whole_brain_mask='mask.nii.gz' # mask.nii.gz: Name of group-level whole brain mask found in cope.feat folder
whole_brain_output='brain'     # Output folder of whole brain beta results

# FSL default values
beta_data='filtered_func_data.nii.gz' # FSL group betas (parameter estimates) file
pe_data='pe'            # FSL prefix of parameter estimate 'stats' files
feat_pe_ext='.nii.gz'   # FSL parameter estimate file extension
group_feat_ext='.gfeat' # FSL group FEAT output folder extension
feat_stats_dir='stats'  # FSL stats folder within '.feat'
cope_dir_name='cope'    # FSL copeX.feat folder name
cope_dir_ext='.feat'    # FSL copeX.feat extension name
#--------------------------- DEFAULT SETTINGS ------------------------------#
max_bg_jobs='5' # Maximum number of background processes (1-10)
text_editors=('kwrite' 'gedit' 'open -a /Applications/TextWrangler.app' 'open' 'nano' 'emacs') # text editor commands in order of preference

IFS_original="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (needed when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
script_usage () { # Script explanation: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: FSL average beta values of higher level FEATs
 Use FSL's ${gre}fslmeants${whi} function with structural masks
 ${red}ASSUMES STANDARD FSL NAMING CONVENTION${whi}

${ora}OUTPUT FOLDERS WITHIN DESIRED FEAT FOLDER(S) UNLESS SPECIFIED WITH ${pur}-out${ora} OPTION${whi}: 
 [${pur}1${whi}] ${gre}${output_beta_dir}${whi} # Main Folder
 
 # Masks are edited with each FEAT brain ${ora}${whole_brain_mask} ${whi}to remove empty voxels
 [${pur}2${whi}] ${gre}${output_beta_dir}/${output_mask_edits}${whi}

 # Each input mask has a folder containing beta files
 [${pur}3${whi}] ${gre}${output_beta_dir}/${ora}MASK_NAME${whi}
 
${ora}OUTPUT FILE${whi}: (${pur}NAMING CONVENTION EXAMPLE: ${ora}betas_mean_brain.csv${whi})
 
${ora}ADVICE${whi}: Create an alias inside your ${ora}${HOME}/.bashrc${whi} file
(e.g. ${gre}alias beta='${script_path}'${whi})

${ora}USAGE${whi}: 
 ${pur}Inputs${whi}: [${ora}1${whi}] None [${ora}2${whi}] text file [${ora}3${whi}] (G)FEAT folder(s) 
 [${ora}1${whi}] ${gre}beta ${whi}# Searches working directory for (G)FEAT folders
 [${ora}2${whi}] ${gre}beta ${ora}feat_paths.txt${whi} # Use (G)FEAT folders listed in file
 [${ora}3${whi}] ${gre}beta ${ora}sub1.feat group.gfeat${whi} # Use (G)FEAT input
 
 ${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-brain${whi} Get beta mean of whole brain mask
 ${pur}-c${whi}   Only use specific '${ora}cope${red}X${ora}.feat${whi}' inputs within GFEAT folder(s)
 [${ora}4${whi}] ${gre}beta ${ora}gfeat_list.txt ${pur}-c ${ora}1 2 5${whi} # cope1.feat, cope2.feat, cope5.feat
 
 ${pur}-cs${whi}  Prevent screen from clearing before script processes
 ${pur}-f${whi}   Force file creation without prompting after ${gre}${wait_time}${whi} seconds
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-m${whi} or ${pur}-mask${whi}   Input structural mask(s) to confine cluster correction
 [${ora}5${whi}] ${gre}beta ${ora}group.gfeat ${pur}-m ${ora}L_DLPFC.nii.gz R_DLPFC.nii.gz${whi}
 
 ${pur}-nb${whi}  Do ${red}NOT ${whi}automatically edit with whole brain mask
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nf${whi}  Do ${red}NOT ${whi}include FEAT path in output file
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-nt${whi}  Prevent script process time from displaying
 ${pur}-nv${whi}  Do ${red}NOT ${whi}include voxel count in output file
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-out${whi} or ${pur}-output${whi} Specify output folder for all output files
 [${ora}6${whi}] ${gre}beta ${ora}group.gfeat ${pur}-output ${ora}~/Desktop ${whi}# Output all files on Desktop
 
 ${pur}-rm${whi}  Remove unwanted beta files generated by this script
 [${ora}7${whi}] ${gre}beta ${pur}-m ${ora}L_DLPFC.nii.gz ${pur}-rm${whi} # Remove files from 'L_DLPFC' mask
   ${red}REMOVE OPTION:${pur}-rm ${red}MUST BE LAST INPUT${whi}
   [${pur}1${whi}] ${pur}except${whi} or ${pur}-except${whi} Remove ${red}ALL${whi} beta files ${red}EXCEPT ${whi}specified files
 [${ora}8${whi}] ${gre}beta ${pur}-m ${ora}L_DLPFC.nii.gz ${pur}-rm except${whi} # Save L_DLPFC beta files

${ora}DEFAULT SETTINGS${whi}:
text editors: 
${gre}${text_editors[@]}${whi}

${ora}REFERENCE${whi}: ${gre}https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Fslutils${whi}
     
${ora}VERSION: ${gre}${version_number}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nt -nm
} # script_usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
script_start_time=$(date +%s)   # Time in seconds
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version_number='2.0'            # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
add_feat_inputs='yes' # 'yes': List FEATs in group output[INPUT: '-nf']
brain_edit='yes'      # 'yes': Edit with whole brain mask[INPUT: '-nb']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
force_create='no'     # 'no' : Create files w/o prompts  [INPUT: '-f']
include_brain='no'    # 'no' : Include whole brain       [INPUT: '-brain']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
read_feat_dir='yes'	  # 'yes': First inputs should be specified feat folders or beta files
remove_betas='no'     # 'no' : Removes beta files        [INPUT: '-rm']
remove_exception='no' # 'no' : Removal all stats except..[INPUT: '-rm e']
show_time='yes'       # 'yes': Display process time      [INPUT: '-nt']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')
voxel_count='yes'     # 'yes': Include output voxel count[INPUT: '-nv']

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluates command line options
	if [ "${1}" == '-brain' 2>/dev/null ] || [ "${1}" == '-c' 2>/dev/null ] || \
	   [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-f' 2>/dev/null ] || \
	   [ "${1}" == '-h' 2>/dev/null ] || [ "${1}" == '--help' 2>/dev/null ] || \
	   [ "${1}" == '-m' 2>/dev/null ] || [ "${1}" == '-mask' 2>/dev/null ] || \
	   [ "${1}" == '-nb' 2>/dev/null ] || [ "${1}" == '-nc' 2>/dev/null ] || \
	   [ "${1}" == '-nf' 2>/dev/null ] || [ "${1}" == '-nv' 2>/dev/null ] || \
	   [ "${1}" == '-nt' 2>/dev/null ] || [ "${1}" == '-nm' 2>/dev/null ] || \
	   [ "${1}" == '-o' 2>/dev/null ] || [ "${1}" == '--open' 2>/dev/null ] || \
	   [ "${1}" == '-out' 2>/dev/null ] || [ "${1}" == '-output' 2>/dev/null ] || \
	   [ "${1}" == '-rm' 2>/dev/null ]; then
		read_feat_dir='no' # Do not search for FEAT directories
		activate_options "${1}"
	elif [ "${read_feat_dir}" == 'yes' 2>/dev/null ]; then
		if [ -f "${1}" ]; then # If list of feat directories or single file input
			skip_feat='no' # Reset value (check for FEAT folder)
			check_pe=($(echo "${1}" |grep "${feat_pe_ext}"))
			if [ "${#check_pe[@]}" -gt '0' ]; then
				pe_inputs+=($(mac_readlink "${1}"))
				skip_feat='yes'
				continue
			fi
			
			if [ "${skip_feat}" == 'no' 2>/dev/null ]; then # Search for FEAT folders
				check_exts=($(cat "${1}" 2>/dev/null |grep -E $(printf "%s\$${IFS}" ${feat_extensions[@]} "${feat_pe_ext}" |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
				if [ "${#check_exts[@]}" -eq '0' ]; then
					bad_inputs+=("input_file:${1}")
				else # Gather existing FEAT directories from files
					for i in ${!check_exts[@]}; do
						check_ext="${check_exts[${i}]}"
						if [ -d "${check_ext}" ] || [ -L "${check_ext}" ]; then
							feat_dirs+=($(mac_readlink "${check_ext}"))
						elif [ -f "${check_ext}" ]; then
							pe_inputs+=($(mac_readlink "${1}"))
						else
							bad_inputs+=("missing_beta_file_or_FEAT_folder:${check_feat_path}")
						fi
					done # for i in ${!check_exts[@]}
				fi # if [ "${#check_exts[@]}" -eq '0' ]
			fi # if [ "${skip_feat}" == 'no' 2>/dev/null ]
		elif [ -d "${1}" ] || [ -L "${1}" ]; then # Gather valid FEAT folders (defined in 'feat_extensions' array)
			check_feat_path=($(echo "${1}" |grep -E $(printf "%s${IFS}" ${feat_extensions[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
			if [ "${#check_feat_path[@]}" -eq '0' ]; then
				bad_inputs+=("invalid_feat_extension:${1}")
			else
				feat_dirs+=($(mac_readlink "${1}"))
			fi
		elif [ "${1:0:1}" == '-' 2>/dev/null ]; then
			bad_inputs+=("invalid_option:${1}")	
		else
			bad_inputs+=("invalid_feat_folder:${1}")
		fi # if [ -f "${1}" ]
	elif [ "${c_in}" == 'yes' 2>/dev/null ]; then # Search for specific cope.feat directories
		check_natural_num "${1}" # Must be whole number > '0'
		c_vals+=("${1}") # Multiple cope.feat directories arise when FSL blocks are NOT combined
	elif [ "${m_in}" == 'yes' 2>/dev/null ]; then
		check_struc_masks $(mac_readlink "${1}") # Average betas within structural mask
	elif [ "${o_in}" == 'yes' 2>/dev/null ]; then # Use specified output folder
		o_in='no' # Reset value
		if [ -d "${1}" ] || [ -L "${1}" ]; then
			output_folder+=($(mac_readlink "${1}"))
		else
			bad_inputs+=("invalid_output_folder:${1}")
		fi
	elif [ "${rm_in}" == 'yes' 2>/dev/null ]; then # Remove unwanted beta files
		if [ "${1}" == 'except' ] || [ "${1}" == '-except' ]; then
			remove_exception='yes' # Remove all files except those specified
		else
			bad_inputs+=("-rm:${1}")
		fi
	else
		bad_inputs+=("${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	c_in='no'  # [-c] copeX.feat folder values (whole number greater than 0)
	m_in='no'  # [-m] structural mask (full path to mask file)
	o_in='no'  # [-out, -output] Output folder for stat input file(s)
	rm_in='no' # [-rm] read in remove options

	if [ "${1}" == '-brain' ]; then
		include_brain='yes'  # Include whole brain beta values
	elif [ "${1}" == '-c' ]; then
		c_in='yes' 		     # Read in user input (cope number(s))
	elif [ "${1}" == '-cs' ]; then
		clear_screen='no'    # Do not clear screen
	elif [ "${1}" == '-f' ]; then
		force_create='yes'   # Create files without prompting
		if [ -z "${wait_time}" ] || ! [ "${wait_time}" -eq "${wait_time}" 2>/dev/null ]; then
			bad_inputs+=("NON-INTEGER_VARIABLE_WITHIN_SCRIPT:wait_time:-f")
		fi # Integer needed for 'seq' command
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'	 # Display help message
	elif [ "${1}" == '-m' ] || [ "${1}" == '-mask' ]; then
		m_in='yes'           # Read in user input (mask file(s))
	elif [ "${1}" == '-nb' ]; then
		brain_edit='no'      # Do NOT include whole brain edit
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no' # Do not display in color
	elif [ "${1}" == '-nf' ]; then
		add_feat_inputs='no' # Do NOT include input FEAT into group beta output
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'	 # Do not display exit message
	elif [ "${1}" == '-nt' ]; then
		show_time='no'		 # Do not display script process time
	elif [ "${1}" == '-nv' ]; then
		voxel_count='no'     # Do NOT include voxel count in output file
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'	 # Open this script
	elif [ "${1}" == '-out' ] || [ "${1}" == '-output' ]; then
		o_in='yes'	         # Read in output folder
	elif [ "${1}" == '-rm' ]; then
		rm_in='yes'		     # Read in user input (remove values)
		remove_betas='yes'   # Remove beta files
	else
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

check_bad_inputs () { # Exit script if bad inputs found
	if [ "${#bad_inputs[@]}" -gt '0' ]; then
		re_enter_input_message ${bad_inputs[@]}
		exit_message 99 -nt
	fi
} # check_bad_inputs

check_natural_num () { # Check whole number greater than 0 (-c and -s options)
	for i_check_natural_num in ${@}; do
		if ! [ "${i_check_natural_num}" -eq "${i_check_natural_num}" 2>/dev/null ] || ! [ "${i_check_natural_num}" -gt '0' 2>/dev/null ]; then
			bad_inputs+=("-c_or_-s_option_non-integer:${i_check_natural_num}")
		fi
	done
} # check_natural_num

check_struc_masks () { # Confirms valid mask file or searches directory for mask files
	for i_check_struc_masks in ${@}; do
		check_masks=() # Reset check_masks array
		if [ -f "${i_check_struc_masks}" ]; then
			check_mask=($(mac_readlink "${i_check_struc_masks}" |grep -E $(printf "%s${IFS}" ${mask_extensions[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
			if [ "${#check_mask[@]}" -eq '0' ]; then
				bad_inputs+=("invalid_mask_extension:${i_check_struc_masks}")
			else
				m_vals+=("${check_mask[0]}")
			fi
		elif [ -d "${i_check_struc_masks}" ]; then
			for j in ${!mask_extensions[@]}; do
				mask_ext=$(echo "${mask_extensions[${j}]}" |sed 's@\.@\\.@g')
				check_masks+=($(find "${i_check_struc_masks}" -maxdepth 1 -type f -name "*${mask_ext}"))
			done
		
			if [ "${#check_masks[@]}" -eq '0' ]; then
				bad_inputs+=("no_masks:${1}") # No valid masks
			else
				m_vals+=($(printf "%s${IFS}" ${check_masks[@]}))
			fi
		else
			bad_inputs+=("invalid_mask_input:${i_check_struc_masks}")
		fi # if [ -f "${i_check_struc_masks}" ]
	done # for i_check_struc_masks in ${@}
} # check_struc_masks

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
			echo "RESTRICTING BACKGROUND PROCESSES TO 10"
			max_bg_jobs='10' # Background jobs should not exceed '10' (Lowers risk of crashing)
		else # If 'max_bg_jobs' not defined as integer
			echo "INVALID VALUE: max_bg_jobs='${max_bg_jobs}'"
			max_bg_jobs='1'
		fi
	
		job_count=($(jobs -p)) # Place job IDs into array
		if ! [ "$?" -eq '0' ]; then
			echo "JOB COUNT FAIL (control_bg_jobs): RESTRICTING BACKGROUND PROCESSES"
			max_bg_jobs='1'
			wait
		else
			if [ "${#job_count[@]}" -ge "${max_bg_jobs}" ]; then
				sleep 0.2
				control_bg_jobs
			fi
		fi # if ! [ "$?" -eq '0' ]
	fi # if [ "${max_bg_jobs}" -eq '1' 2>/dev/null ]
} # control_bg_jobs

dir_change () { # Execute FSL commands in output directory (Avoid special characters in file path)
	cd_out_dir="${1}"
	wd=$(pwd)
	
	if ! [ -d "${cd_out_dir}" ] && ! [ -L "${cd_out_dir}" ]; then
		echo "${red}MISSING DIRECTORY: ${ora}${cd_out_dir}${whi}"
	else
		cd "${cd_out_dir}"
	fi
} # dir_change

display_values () { # Display output with numbers
	if [ "${#@}" -gt '0' ]; then
		val_count=($(seq 1 1 ${#@}))
		vals_and_count=($(paste -d "${IFS}" <(printf "%s${IFS}" ${val_count[@]}) <(printf "%s${IFS}" ${@})))
		printf "${pur}[${ora}%s${pur}] ${gre}%s${IFS}${whi}" ${vals_and_count[@]}
	fi
} # display values

edit_masks () { # edit masks with whole brain mask (to remove empty voxels)
	brain="${1}"           # Group-level whole brain mask
	input_mask="${2}"      # Mask to edit (if voxels extend beyond whole brain mask)
	output_mask_dir="${3}" # Output mask directory
	output_mask_file="${output_mask_dir}/"$(basename "${input_mask%.nii*}")".nii.gz"
	output_mask_edit="${output_mask_dir}/"$(basename "${input_mask%.nii*}")"${output_edit_name}.nii.gz"

	dir_change $(dirname "${input_mask}") # Avoid special characters in file path
	base_input_mask=$(basename "${input_mask}")
	mask_dim1=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/pixdim1/ {print $2}') # Mask dimension
	mask_dim2=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/pixdim2/ {print $2}') # Mask dimension
	mask_dim3=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/pixdim3/ {print $2}') # Mask dimension
	mask_orient1=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/sto_xyz:1/ {print $5}') # Brain orientation
	mask_orient2=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/sto_xyz:2/ {print $5}') # Brain orientation
	mask_orient3=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/sto_xyz:3/ {print $5}') # Brain orientation
	mask_orient4=$("${FSLDIR}/bin/fslhd" "${base_input_mask}" |awk '/sto_xyz:4/ {print $5}') # Brain orientation
	cd "${wd}" # wd defined in 'dir_change'

	if [ -z "${mask_dim1}" ] || [ -z "${mask_dim2}" ] || \
	   [ -z "${mask_dim3}" ]; then
		echo "${red}MASK DIMENSIONS UNKNOWN: ${ora}${input_mask}${whi}"
		continue
	fi
				
	if [ -z "${mask_orient1}" ] || [ -z "${mask_orient2}" ] || \
	   [ -z "${mask_orient3}" ] || [ -z "${mask_orient4}" ]; then
		echo "${red}MASK ORIENTATIONS UNKNOWN: ${ora}${input_mask}${whi}"
		continue
	fi

	# Check input mask dimensions match whole brain mask dimensions
	if ! [ "${brain_dim1}" == "${mask_dim1}" ] || ! [ "${brain_dim2}" == "${mask_dim2}" ] || \
	   ! [ "${brain_dim3}" == "${mask_dim3}" ]; then
		echo "${red}MASK DIMENSIONS DIFFER FROM WHOLE BRAIN: ${ora}${input_mask}${whi}"
		continue
	fi
	
	# Check input mask orientation (must be registered even if dimensions are equal)
	if ! [ "${brain_orient1}" == "${mask_orient1}" ] || ! [ "${brain_orient2}" == "${mask_orient2}" ] || \
	   ! [ "${brain_orient3}" == "${mask_orient3}" ] || ! [ "${brain_orient4}" == "${mask_orient4}" ]; then
		echo "${red}MASK ORIENTATIONS DIFFER FROM WHOLE BRAIN: ${ora}${input_mask}${whi}"
		continue
	fi

	if [ -f "${output_mask_file}" ]; then # Remove old mask file
		rm "${output_mask_file}" 2>/dev/null
	fi

	cp "${input_mask}" "${output_mask_file}" || vital_error_loop "${output_mask_file}" "${LINENO}"
	
	dir_change "${cope_dir}" # Avoid special characters in file path
	"${FSLDIR}/bin/fslmaths" $(echo "${brain}" |sed "s@^${cope_dir}/@@g") -mas $(echo "${output_mask_file}" |sed "s@^${cope_dir}/@@g") $(echo "${output_mask_edit}" |sed "s@^${cope_dir}/@@g") || vital_error_loop "${output_mask_edit}" "${LINENO}"
	cd "${wd}" # wd defined in 'dir_change'
} # edit_masks

mac_readlink () { # Get absolute path of a file
	dir_mac=$(dirname "${1}")   # Directory path
	file_mac=$(basename "${1}") # Filename
	wd_mac="$(pwd)" # Working directory path

	if [ -d "${dir_mac}" ]; then
		cd "${dir_mac}"
		echo "$(pwd)/${file_mac}" # Print full path
		cd "${wd_mac}" # Change directory back to original directory
	else
		echo "${1}" # Print input
	fi
} # mac_readlink

mean_betas () { # Average beta values with mask input
	beta_input="${1}"
	input_mask="${2}"
	output_file="${3}"
	
	mask_name=$(basename "${input_mask%\.nii*}") # Remove .nii or .nii.gz extension
	mean_vals=($("${FSLDIR}/bin/fslmeants" -i "${beta_input}" -m "${input_mask}"))
	
	if [ "${voxel_count}" == 'yes' 2>/dev/null ]; then
		voxel_count=$("${FSLDIR}/bin/fslstats" "${input_mask}" -V |awk '{print $1}') # Get voxel count
		mask_name="${mask_name}_${voxel_count}${vxl_name}"
	fi
	
	if [ "${#design_inputs[@]}" -eq "${#mean_vals[@]}" ]; then
		data_header="${output_sub_header},${mask_name}"
		data_values=($(paste -d ',' <(printf "%s${IFS}" ${design_inputs[@]}) <(printf "%s${IFS}" ${mean_vals[@]})))
	else
		data_header="${mask_name}"
		data_values=($(printf "%s${IFS}" ${mean_vals[@]}))
	fi
	
	printf "%s${IFS}" "${data_header}" ${data_values[@]} > "${output_file}"
	if [ "$?" -eq '0' ] && [ -f "${output_file}" ]; then
		echo "${gre}CREATED: ${ora}${output_file}${whi}"
	else
		echo "${red}NOT CREATED: ${ora}${output_file}${whi}"
	fi
} # mean_betas

open_text_editor () { # Opens input file
	file_to_open="${1}"
	valid_text_editor='no'
	
	if [ -f "${file_to_open}" ]; then
		for i in ${!text_editors[@]}; do # Loop through indices
			${text_editors[i]} "${file_to_open}" 2>/dev/null &
			pid="$!" # Background process ID
			check_text_pid=($(ps "${pid}" |grep "${pid}")) # Check if pid is running
			
			if [ "${#check_text_pid[@]}" -gt '0' ]; then
				valid_text_editor='yes'
				break
			fi
		done

		if [ "${valid_text_editor}" == 'no' 2>/dev/null ]; then
			echo "${red}NO VALID TEXT EDITORS:${whi}"
			printf "${ora}%s${IFS}${whi}" ${text_editors[@]}
			exit_message 98 -nh -nm -nt
		fi
	else
		echo "${red}MISSING FILE: ${ora}${file_to_open}${whi}"
	fi
} # open_text_editor

slow_grep_v () { # Use for-loop when grep argument list is too long
	all_vals=(${@})
	
	for i_slow_grep_v in ${!check_rm_vals[@]}; do # Remove values one at a time
		all_vals=($(printf "%s${IFS}" ${all_vals[@]} |grep -E -v "^${check_rm_vals[${i_slow_grep_v}]}$"))
	done
	
	all_rm_vals+=(${all_vals[@]})
} # slow_grep_v

vital_error_loop () { # vital error message inside of loop
	error_file="${1}"
	error_line="${2}"
	echo "${red}COULD NOT CREATE (${error_line}): ${ora}${error_file}${whi}"
	continue
} # vital_error_loop

vital_file () { # exits script if an essential file is missing
	for vitals; do
		if ! [ -e "${vitals}" 2>/dev/null ]; then
			bad_files+=("${vitals}")
		fi
	done
	
	if [ "${#bad_files[@]}" -gt '0' ]; then
		echo "${red}MISSING ESSENTIAL FILE(S):${whi}"
		printf "${pur}%s${IFS}${whi}" ${bad_files[@]}
		exit_message 97 -nh -nm -nt
	fi
} # vital_file

#-------------------------------- MESSAGES ---------------------------------#
exit_message () { # Message before exiting script
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
	
	wait # Waits for background processes to finish before exiting

	# Suggest help message
	if [ "${suggest_help}" == 'yes' 2>/dev/null ]; then
		echo "${ora}TO DISPLAY HELP MESSAGE TYPE: ${gre}${script_path} -h${whi}"
	fi
	
	# Display exit message
	if ! [ "${display_exit}" == 'no' 2>/dev/null ]; then # Exit message
		echo "${pur}EXITING SCRIPT:${ora} ${script_path}${whi}"
	fi
	
	# Display script process time
	if [ "${show_time}" == 'yes' 2>/dev/null ]; then # Script time message
		script_time_func 2>/dev/null
	fi
	
	printf "${formatreset}\n"
	IFS="${IFS_original}" # Reset IFS
	exit "${exit_type}"
} # exit_message

control_c () { # Function activates after 'ctrl + c'
	echo "${red}FINISHING CURRENT BACKGROUND PROCESSES BEFORE CRASHING${whi}"
	exit_message 96 -nm -nt
} # control_c

re_enter_input_message () { # Displays invalid input message
	clear
	echo "${red}INVALID INPUT:${whi}"
	printf "${ora}%s${IFS}${whi}" ${@}
	echo "${pur}PLEASE RE-ENTER INPUT${whi}"
} # re_enter_input_message

script_time_func () { # Script process time calculation
	func_end_time=$(date +%s) # Time in seconds
	user_input_time="${1}"
	valid_display_time='yes'
	
	if ! [ -z "${user_input_time}" ] && [ "${user_input_time}" -eq "${user_input_time}" 2>/dev/null ]; then
		func_start_time="${user_input_time}"
	elif ! [ -z "${script_start_time}" ] && [ "${script_start_time}" -eq "${script_start_time}" 2>/dev/null ]; then
		func_start_time="${script_start_time}"
	else # If no integer input or 'script_start_time' undefined
		valid_display_time='no'
	fi
	
	if [ "${valid_display_time}" == 'yes' ]; then
		script_process_time=$((${func_end_time} - ${func_start_time}))
		days=$((${script_process_time} / 86400))
		hours=$((${script_process_time} % 86400 / 3600))
		mins=$((${script_process_time} % 3600 / 60))
		secs=$((${script_process_time} % 60))
	
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
	fi # if [ "${valid_display_time}" == 'yes' ]
} # script_time_func

#---------------------------------- CODE -----------------------------------#
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

# Crash if essential arrays are empty
if [ "${#feat_extensions[@]}" -eq '0' ] || [ "${#mask_extensions[@]}" -eq '0' ]; then
	echo "${red}ARRAYS MUST HAVE AT LEAST 1 INPUT${whi}"
	echo "${ora}feat_extensions:${gre}${#feat_extensions[@]}${whi}"
	echo "${ora}mask_extensions:${gre}${#mask_extensions[@]}${whi}"
	exit_message 1 -nm -nt
else # Sort unique values
	feat_extensions=($(printf "%s${IFS}" ${feat_extensions[@]} |sort -u))
	mask_extensions=($(printf "%s${IFS}" ${mask_extensions[@]} |sort -u))
fi # if [ "${#feat_extensions[@]}" -eq '0' ] || [ "${#mask_extensions[@]}" -eq '0' ]

for inputs; do # Reads through all inputs
	option_eval "${inputs}"
done

if ! [ "${clear_screen}" == 'no' 2>/dev/null ]; then
	clear     # Clears screen unless activation of input option: '-cs'
fi

color_formats # Activates or inhibits colorful output

# Display help message or open file
if [ "${activate_help}" == 'yes' 2>/dev/null ]; then # '-h' or '--help'
	script_usage
elif [ "${open_script}" == 'yes' 2>/dev/null ]; then # '-o' or '--open'
	open_text_editor "${script_path}" ${text_editors[@]}
	exit_message 0 -nm -nt
elif [ -z "${FSLDIR}" ]; then # Check $FSLDIR
	echo "${red}UNDEFINED VARIABLE: ${ora}\$FSLDIR ${pur}(${ora}source '${gre}fsl.sh${ora}' script${pur})${whi}"
	exit_message 2 -nm -nt
fi

#---------------- CHECK FOR VALID VALUES BEFORE PROCESSING -----------------#
check_bad_inputs
vital_file "${FSLDIR}/bin/fslhd" "${FSLDIR}/bin/fslmaths" "${FSLDIR}/bin/fslmeants" "${FSLDIR}/bin/fslstats" "${FSLDIR}/bin/smoothest"
echo "${ora}RUNNING: ${gre}${script_path}${whi}"

# Check FEAT directories
if [ "${#feat_dirs[@]}" -eq '0' ] && [ "${#pe_inputs[@]}" -eq '0' ]; then
	for i in ${!feat_extensions[@]}; do # Get all feat directories in working directory
		feat_ext=$(echo "${feat_extensions[${i}]}" |sed 's@\.@\\.@g')
		feat_dirs+=($(find "$(pwd)" -maxdepth 1 -name "*${feat_ext}" |grep -v "^$(pwd)$")) # Find in linked folders too
	done
fi

if [ "${#feat_dirs[@]}" -eq '0' ] && [ "${#pe_inputs[@]}" -eq '0' ]; then # Exit if no valid FEAT directories found
	echo "${red}NO FEAT FOLDERS FOUND WITH THE FOLLOWING EXTENSIONS:${whi}"
	display_values ${feat_extensions[@]}
	exit_message 3 -nt
fi

if [ "${#output_folder[@]}" -eq '0' ]; then
	if [ "${#pe_inputs[@]}" -gt '0' ]; then
		final_output="$(pwd)"
	fi
elif [ "${#output_folder[@]}" -eq '1' ]; then
	final_output="${output_folder[0]}"
else # Multiple output folders
	echo "${red}CAN ONLY INPUT 1 OUTPUT FOLDER${whi}"
	display_values "${output_folder[@]}"
	exit_message 4 -nt
fi

# Check cope.feat directories
if [ "${#c_vals[@]}" -eq '0' ]; then # Which cope.feat directories to use
	if [ "${#default_cope_files[@]}" -eq '0' ]; then
		c_vals=('^') # Used with 'grep -E' (gets all cope values)
	else
		c_vals=($(printf "${cope_dir_name}%s${cope_dir_ext}${IFS}" ${default_cope_files[@]} |sort -u)) # Sort unique cope.feat directories
	fi
else
	c_vals=($(printf "${cope_dir_name}%s${cope_dir_ext}${IFS}" ${c_vals[@]} |sort -u)) # Sort unique cope.feat directories
fi # if [ "${#c_vals[@]}" -eq '0' ]

# Check structural mask files
if [ "${#m_vals[@]}" -eq '0' ]; then # Which additional structural masks to use	
	if [ "${#default_masks[@]}" -gt '0' ]; then
		echo "${ora}CHECKING DEFAULT MASKS${whi}"
		display_values ${default_masks[@]}
		check_struc_masks ${default_masks[@]}
		check_bad_inputs
	fi
fi

if [ "${#m_vals[@]}" -gt '0' ]; then
	m_vals=($(printf "%s${IFS}" ${m_vals[@]} |sort -u)) # Sort unique values
elif [ "${#pe_inputs[@]}" -gt '0' ]; then
	echo "${red}MUST INPUT MASK FILE (${pur}-m${red}) WITH STAT FILE INPUT${whi}"
	exit_message 5 -nt
fi

trap control_c SIGINT 2>/dev/null # Finishes background processes before crashing
#---------------------------- FIND BETA FILES ------------------------------#
# Create 'grep -E' input of cope.feat directories
cope_filter=$(printf "%s\$${IFS}" ${c_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed -e 's/|$//' -e 's/\^\$/^/g')
miss_count='0' # Track number of missing beta files

for i in ${!feat_dirs[@]}; do
	feat_dir="${feat_dirs[${i}]}"
	cope_find=($(find "${feat_dir}" -name "${cope_dir_name}*${cope_dir_ext}" |grep -E "${cope_filter}" |sed 's@//@/@g')) # Find in linked folders too

	if [ "${#cope_find[@]}" -eq '0' ]; then # If lower-level FEAT or missing desired cope.feats
		if [ "${c_vals[0]}" == '^' ]; then # If no '-c' inputs, ignore null results
			rm_beta_dir=("${feat_dir}/${output_beta_dir}") # If removing files
			cope_find=("${feat_dir}/${feat_stats_dir}") # add 'stats' folder
		fi
	else # Sort unique values
		rm_beta_dir=($(printf "%s/${output_beta_dir}${IFS}" ${cope_find[@]} |sort -u)) # If removing files
		cope_find=($(printf "%s${IFS}" ${cope_find[@]} |sort -u))
	fi

	for j in ${!cope_find[@]}; do
		in_feat="${cope_find[${j}]}"
		if [ -d "${in_feat}" ] || [ -L "${in_feat}" ]; then
			pe_dirs+=("${in_feat}")
		else
			miss_count=$((${miss_count} + 1)) # Track number of missing stats folders 
			echo "${red}MISSING BETA FOLDER: [${whi}${miss_count}${red}] ${ora}${in_feat}${whi}"
		fi
	done # for j in ${!cope_find[@]}

	for j in ${!rm_beta_dir[@]}; do
		in_beta="${rm_beta_dir[${j}]}"
		if [ -d "${in_beta}" ] || [ -L "${in_beta}" ]; then # Beta folders to remove files from
			rm_beta_dirs+=("${in_beta}")
		fi
	done # for j in ${!rm_beta_dir[@]}
done # for i in ${!feat_dirs[@]}

if [ "${#pe_inputs[@]}" -gt '0' ]; then
	beta_files+=($(printf "%s${IFS}" "${pe_inputs[@]}" |sort -u))
	
	for i in ${!beta_files[@]}; do
		check_beta_dir=$(dirname "${pe_inputs[${i}]}" |sed 's,/${feat_stats_dir}$,,g')"/${output_beta_dir}"
		if [ -d "${check_beta_dir}" ] || [ -L "${check_beta_dir}" ]; then
			rm_beta_dirs+=("${check_beta_dir}")
		fi
	done # for i in ${!pe_inputs[@]}
fi # Add input beta file(s)

if [ "${remove_betas}" == 'yes' 2>/dev/null ]; then # Remove files
	if ! [ -z "${final_output}" ]; then
		manual_beta_dir="${final_output}/${output_beta_dir}"
		if [ -d "${manual_beta_dir}" ] || [ -L "${manual_beta_dir}" ]; then
			rm_beta_dirs+=("${manual_beta_dir}")
		fi
	fi

	if [ "${#rm_beta_dirs[@]}" -eq '0' ]; then # Crash if no inputs
		echo "${red}NO '${ora}${output_beta_dir}${red}' DIRECTORIES FOUND TO REMOVE${whi}"
		exit_message 6 -nt
	else # Sort unique values
		rm_beta_dirs=($(printf "%s${IFS}" ${rm_beta_dirs[@]} |sort -u))
	fi
	
	echo "${ora}SEARCHING FOR FILES TO REMOVE...${whi}"
	
	# Generate remove filters
	m_filt='^' # grep '^' gets all values

	if [ "${#m_vals[@]}" -gt '0' ] || [ "${include_brain}" == 'yes' 2>/dev/null ]; then # Remove specified masks only
		m_filt=() # Reset array
		
		if [ "${include_brain}" == 'yes' 2>/dev/null ]; then
			m_filt=("${whole_brain_output%.nii*}")
		fi # include whole brain mask
		
		for i in ${!m_vals[@]}; do
			m_val="${m_vals[${i}]}"
			for j in ${!mask_extensions[@]}; do
				mask_ext=$(echo "${mask_extensions[${j}]}" |sed 's@\.@\\.@g')
				m_filt+=($(basename "${m_val%${mask_ext}}")) # mask name only
			done
		done # for i in ${!m_vals[@]}
		
		m_filt=$(printf "%s${IFS}" ${m_filt[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//g')
	fi # if [ "${#m_vals[@]}" -gt '0' ]
	
	for i in ${!rm_beta_dirs[@]}; do
		rm_beta_dir="${rm_beta_dirs[${i}]}"
		all_betas=($(find "${rm_beta_dir}/" -type f |sed 's@//@/@g')) # Find in linked folders too
		
		if [ "${#all_betas[@]}" -eq '0' ]; then
			continue # No files to remove
		else # Filter files
			check_rm_vals=($(printf "%s${IFS}" ${all_betas[@]} |grep -E "${m_filt}"))
		fi

		if [ "${remove_exception}" == 'yes' 2>/dev/null ]; then
			if [ "${#check_rm_vals[@]}" -eq '0' ]; then # Remove all files
				all_rm_vals+=($(printf "%s${IFS}" ${all_betas[@]}))
			elif [ "${#check_rm_vals[@]}" -eq "${#all_betas[@]}" ]; then # Keep all files
				preserved_files+=($(printf "%s${IFS}" ${all_betas[@]}))
			else # Reverse selection with 'grep -v' (basename of files). Use 'for loop' if error
				all_rm_vals+=($(printf "%s${IFS}" ${all_betas[@]} |grep -E -v $(printf "%s\$${IFS}" ${check_rm_vals[@]} |sed "s@${rm_beta_dir}@@g" |tr "${IFS}" '|' |sed 's/|$//g'))) || slow_grep_v ${all_betas[@]}
				preserved_files+=(${check_rm_vals[@]})
			fi
		else
			all_rm_vals+=($(printf "%s${IFS}" ${check_rm_vals[@]}))
		fi # if [ "${remove_exception}" == 'yes' 2>/dev/null ]
	done # for i in ${!rm_beta_dirs[@]}
	
	all_rm_vals=($(printf "%s${IFS}" ${all_rm_vals[@]} |sort -u))

	proceed='no'
	until [ "${proceed}" == 'yes' 2>/dev/null ]; do
	
		echo "${ora}FOUND ${gre}${#all_rm_vals[@]} ${ora}FILE(S) TO REMOVE${whi}"
		
		if [ "${remove_exception}" == 'yes' 2>/dev/null ]; then
			echo "${ora}EXCEPTION USED: RETAINING ${gre}${#preserved_files[@]} ${ora}SPECIFIED FILE(S)${whi}"
		fi

		echo "${pur}MASK(S): ${whi}"
		display_values $(echo "${m_filt}" |tr '|' "${IFS}" |sed -e 's@^_@@g' -e 's/_$//g' -e 's/^\^$/ALL MASKS/g')

		echo "${ora}[${gre}ls${ora}] LIST ${gre}${#all_rm_vals[@]} ${ora}FILES TO REMOVE${whi}"
		echo "${ora}[${gre}rm${ora}] REMOVE ${gre}${#all_rm_vals[@]} ${ora}FILES${whi}"
		
		if [ "${remove_exception}" == 'yes' 2>/dev/null ] && [ "${#preserved_files[@]}" -gt '0' ]; then
			echo "${ora}[${gre}v${ora}]  VIEW ${gre}${#preserved_files[@]} ${ora}FILES TO KEEP${whi}"
		fi
		
		if [ "${#all_rm_vals[@]}" -eq '0' ]; then
			exit_message 0
		fi # Exit script if no files found
		
		echo "${ora}[${gre}x${ora}]  EXIT SCRIPT${whi}"
		printf "${ora}ENTER OPTION:${whi}"
		read -r user_remove
		
		if [ "${user_remove}" == 'l' 2>/dev/null ] || [ "${user_remove}" == 'ls' 2>/dev/null ]; then
			display_values ${all_rm_vals[@]}
		elif [ "${user_remove}" == 'rm' 2>/dev/null ]; then
			proceed='yes'
			if [ "${#all_rm_vals[@]}" -gt '0' ]; then # If there are files to remove
				echo "${red}REMOVING ${gre}${#all_rm_vals[@]} ${ora}FILE(S)${whi}"
					
				for i in "${!all_rm_vals[@]}"; do # Slow but compatible
					rm "${all_rm_vals[${i}]}" &
					control_bg_jobs
				done
					
				wait # Wait for background processes to finish
			else
				echo "${red}NO FILES TO REMOVE${whi}"
			fi # if [ "${#all_rm_vals[@]}" -gt '0' ]
			
			for i in ${!rm_beta_dirs[@]}; do
				in_rm_dir="${rm_beta_dirs[${i}]}"
				check_empty=($(find "${in_rm_dir}" -type d))
				for j in ${!check_empty[@]}; do
					rmdir "${check_empty[${j}]}" 2>/dev/null # Remove empty folders
				done
				
				rmdir "${in_rm_dir}" 2>/dev/null
			done
		elif [ "${user_remove}" == 'q' 2>/dev/null ] || [ "${user_remove}" == 'x' 2>/dev/null ]; then
			exit_message 0 -nt
		elif [ "${user_remove}" == 'v' 2>/dev/null ]; then
			display_values ${preserved_files[@]}
		else
			re_enter_input_message "${user_remove}"
		fi # if [ "${user_remove}" == 'l' 2>/dev/null ] || [ "${user_remove}" == 'ls' 2>/dev/null ]
	done # until [ "${proceed}" == 'yes' 2>/dev/null ]
else # Check beta directories
	if [ "${include_brain}" == 'no' 2>/dev/null ] && [ "${#m_vals[@]}" -eq '0' ]; then
		echo "${red}MUST SPECIFY INPUT MASK(S) ${pur}-m${red} OR WHOLE BRAIN ${pur}-brain${whi}"
		exit_message 7 -nt
	fi
	
	if [ "${#pe_dirs[@]}" -eq '0' ] && [ "${#beta_files[@]}" -eq '0' ]; then
		echo "${red}NO VALID '${ora}beta${red}' FOLDERS OR FILES FOUND${whi}"
		exit_message 8 -nt
	elif [ "${#pe_dirs[@]}" -gt '0' ]; then
		echo "${ora}SEARCHING FOR BETA FILES...${whi}"
		for i in ${!pe_dirs[@]}; do
			pe_dir="${pe_dirs[${i}]}"
			check_lower_level=($(echo "${pe_dir}" |grep "/${fsl_stats_dir}$"))
			if [ -d "${pe_dir}" ]; then
				if [ "${#check_lower_level[@]}" -gt '0' ]; then
					find_pe=($(find "${pe_dir}" -maxdepth 1 -type f -name "${pe_data}*${feat_pe_ext}"))
					if [ "${#find_pe[@]}" -gt '0' ]; then
						in_pes+=($(printf "%s${IFS}" ${find_pe[@]} |sort -u))
					else
						echo "${red}MISSING '${ora}${pe_data}${pur}X${ora}${feat_pe_ext}${red}' FILES: ${gre}${pe_dir}${whi}"
					fi
				else
					find_filtered_func=($(find "${pe_dir}" -maxdepth 1 -type f -name "${beta_data}"))
					if [ "${#find_filtered_func[@]}" -gt '0' ]; then
						in_pes+=($(printf "%s${IFS}" ${find_filtered_func[@]} |sort -u))
					else
						echo "${red}MISSING '${ora}${beta_data}${red}' FILE: ${gre}${pe_dir}${whi}"
					fi
				fi
			else
				echo "${red}MISSING FOLDER: ${ora}${pe_dir}${whi}"
			fi
		done # for i in ${!pe_dirs[@]}
	fi # if [ "${#pe_dirs[@]}" -eq '0' ] && [ "${#beta_files[@]}" -eq '0' ]
	
	if [ "${#beta_files[@]}" -gt '0' ]; then
		in_pes+=($(printf "%s${IFS}" ${beta_files[@]} |sort -u))
	fi # if [ "${#beta_files[@]}" -gt '0' ]
	
	if [ "${#in_pes[@]}" -eq '0' ]; then
		echo "${red}NO BETA FILES FOUND${whi}"
		exit_message 9 -nt
	fi
	
	if [ "${include_brain}" == 'no' 2>/dev/null ]; then # Do not include whole brain output
		total_extractions=$(echo |awk "{print ${#in_pes[@]}*${#m_vals[@]}}")
	else # Include whole brain analysis
		if [ "${#m_vals[@]}" -eq '0' ]; then # whole brain only
			total_extractions="${#in_pes[@]}"
		else # whole brain AND mask values
			total_extractions=$(echo |awk "{print ${#in_pes[@]}*(${#m_vals[@]} + 1)}")
		fi
	fi

	proceed='no' # Wait for user input to continue
	until [ "${proceed}" == 'yes' ]; do
		echo "${gre}FOUND ${ora}${#in_pes[@]} ${gre}BETA FILE(S)${whi}"
		
		if ! [ -z "${final_output}" ]; then
			echo "${pur}OUTPUT FOLDER FOR ${red}ALL ${pur}FILES: ${ora}${final_output}${whi}"
		fi
		
		echo "${pur}MASK(S): ${whi}"
		if [ "${include_brain}" == 'no' 2>/dev/null ]; then  # Do not include whole brain output
			display_values ${m_vals[@]}
		else # Search for whole brain in FEAT folder(s)
			display_values "${whole_brain_output}" ${m_vals[@]}
		fi

		if [ "${force_create}" == 'yes' 2>/dev/null ]; then
			echo "${ora}EXTRACTING ${gre}${total_extractions} ${ora}TIME(S) USING ${gre}${#in_pes[@]}${ora} BETA FILES${whi}"
			echo "${gre}EXTRACTING IN ${pur}${wait_time} ${gre}SECONDS: ${whi}"
			
			for i in $(seq 1 1 "${wait_time}"); do
				printf "${i} "
				sleep 1
			done # Allow user to crash script if needed
			
			printf '\n'
			proceed='yes'
		else # Prompt user
			echo "${ora}[${gre}e${ora}]  EXTRACT BETAS ${gre}${total_extractions} ${ora}TIME(S) USING ${gre}${#in_pes[@]}${ora} BETA FILES?${whi}"
			echo "${ora}[${gre}ls${ora}] LIST ${gre}${#in_pes[@]}${ora} BETA FILES?${whi}"
			echo "${ora}[${gre}x${ora}]  EXIT SCRIPT${whi}"
			printf "${ora}ENTER OPTION:${whi}"
		
			read -r stat_status
			if [ "${stat_status}" == 'e' 2>/dev/null ]; then
				proceed='yes'
			elif [ "${stat_status}" == 'l' 2>/dev/null ] || [ "${stat_status}" == 'ls' 2>/dev/null ]; then
				display_values ${in_pes[@]}
			elif [ "${stat_status}" == 'q' 2>/dev/null ] || [ "${stat_status}" == 'x' 2>/dev/null ]; then
				exit_message 0 -nt
			else
				re_enter_input_message "${stat_status}"
			fi
		fi
	done # until [ "${proceed}" == 'yes' ]
	
	file_increment='0'
	for i in ${!in_pes[@]}; do # Extract betas from all input files
		design_inputs=() # Reset array
		pe_file="${in_pes[${i}]}"
		base_pe=$(basename "${pe_file}")
		dir_pe=$(dirname "${pe_file}")'/' # Add '/' to remove full folder in "${cope_dir}"
		file_count="${file_increment}" # Increment file count each iteration
		
		if [ "${base_pe}" == "${beta_data}" 2>/dev/null ]; then
			if [ "${add_feat_inputs}" == 'yes' 2>/dev/null ]; then
				find_design=($(find "${dir_pe}" -maxdepth 1 -type f -name "${design_file}"))
				if [ "${#find_design[@]}" -eq '1' ]; then
					design_inputs=($(grep "${feat_dir_code}" "${find_design[0]}" |awk -F '"' '{print $2}'))
				fi
			fi # Add lower-level FEAT inputs into output beta file
			
			beta_out_head="${output_header}"
		else # include beta filename if not "${beta_data}" file
			beta_out_head="${output_header}"$(basename "${pe_file%.nii*}")
		fi
		
		if [ "${include_brain}" == 'yes' 2>/dev/null ]; then
			file_increment=$(echo |awk "{print ${file_increment} + (1 + ${#m_vals[@]})}")
		else # Do not include brain mask
			file_increment=$(echo |awk "{print ${file_increment} + ${#m_vals[@]}}")
		fi
		
		cope_dir="${dir_pe%/${feat_stats_dir}/*}"
		
		if [ -z "${final_output}" ]; then
			out_dir=$(echo "${cope_dir}" |sed 's,/$,,g') # Remove trailing '/'
		else
			out_dir="${final_output}"
		fi
		
		check_complete_dir=($(printf "%s${IFS}" ${completed_dirs[@]} |grep "^${out_dir}$")) # Do not repeat mask edits
		completed_dirs+=("${cope_dir}")

		# Create mask edits
		if [ "${#check_complete_dir[@]}" -eq '0' ]; then
			wait # Wait for background processes to finish
			brain_mask="${cope_dir}/${whole_brain_mask}"
			edit_mask_dir="${out_dir}/${output_beta_dir}/${output_mask_edits}"
			
			if [ "${brain_edit}" == 'no' 2>/dev/null ]; then
				brain_master=''
			elif ! [ -f "${brain_mask}" ] && [ "${#pe_inputs[@]}" -eq '0' ]; then # Edit with brain mask to avoid empty voxels
				echo "${red}MISSING WHOLE BRAIN MASK: ${ora}${brain_mask}${whi}"
				continue
			fi
			
			if ! [ -d "${edit_mask_dir}" ]; then
				mkdir -p "${edit_mask_dir}" || vital_error_loop "${edit_mask_dir}" "${LINENO}"
			fi
			
			if ! [ -f "${brain_mask}" ] && [ "${#pe_inputs[@]}" -gt '0' ]; then
				brain_master='' # No master brain file (use mask inputs only)
			elif [ "${brain_edit}" == 'yes' 2>/dev/null ] || [ "${include_brain}" == 'yes' 2>/dev/null ]; then
				brain_master="${edit_mask_dir}/${whole_brain_output%.nii*}.nii.gz"
				
				cp "${brain_mask}" "${brain_master}" || vital_error_loop "${brain_master}" "${LINENO}"
				
				dir_change $(dirname "${brain_master}") # Avoid special characters in file path
				base_brain=$(basename "${brain_master}")
				
				"${FSLDIR}/bin/fslmaths" "${base_brain}" -bin "${base_brain}" || vital_error_loop "${brain_master}" "${LINENO}" # Binarize mask
				echo "${gre}CREATED MASK: ${ora}${brain_master}${whi}"
				
				brain_dim1=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/pixdim1/ {print $2}') # Brain mask dimension
				brain_dim2=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/pixdim2/ {print $2}') # Brain mask dimension
				brain_dim3=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/pixdim3/ {print $2}') # Brain mask dimension
				brain_orient1=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/sto_xyz:1/ {print $5}') # Brain orientation
				brain_orient2=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/sto_xyz:2/ {print $5}') # Brain orientation
				brain_orient3=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/sto_xyz:3/ {print $5}') # Brain orientation
				brain_orient4=$("${FSLDIR}/bin/fslhd" "${base_brain}" |awk '/sto_xyz:4/ {print $5}') # Brain orientation
				cd "${wd}" # wd defined in 'dir_change'
				
				if [ -z "${brain_dim1}" ] || [ -z "${brain_dim2}" ] || \
				   [ -z "${brain_dim3}" ]; then
					echo "${red}MASK DIMENSIONS UNKNOWN: ${ora}${brain_master}${whi}"
					continue
				fi
				
				if [ -z "${brain_orient1}" ] || [ -z "${brain_orient2}" ] || \
				   [ -z "${brain_orient3}" ] || [ -z "${brain_orient4}" ]; then
					echo "${red}MASK ORIENTATIONS UNKNOWN: ${ora}${brain_master}${whi}"
					continue
				fi
			fi # if ! [ -f "${brain_mask}" ]
		
			if [ "${#m_vals[@]}" -gt '0' ]; then
				echo "${ora}EDITING ${gre}${#m_vals[@]} ${ora}MASKS: ${gre}${edit_mask_dir}${whi}"
				for j in ${!m_vals[@]}; do
					m_val="${m_vals[${j}]}"
					
					if [ -z "${brain_master}" ]; then # Copy and binarize mask (no brain edits)
						output_mask_file="${edit_mask_dir}/"$(basename "${m_val%.nii*}")".nii.gz"
						output_mask_edit="${edit_mask_dir}/"$(basename "${m_val%.nii*}")"${output_edit_name}.nii.gz"
						
						if [ -f "${output_mask_file}" ]; then # Remove old mask file
							rm "${output_mask_file}" 2>/dev/null
						fi

						cp "${m_val}" "${output_mask_file}" || vital_error_loop "${output_mask_file}" "${LINENO}"
						dir_change $(dirname "${output_mask_file}") # Avoid special characters in file path
						base_brain=$(basename "${output_mask_file}")
				
						"${FSLDIR}/bin/fslmaths" "${base_brain}" -bin $(basename "${output_mask_edit}") || vital_error_loop "${output_mask_edit}" "${LINENO}" # Binarize mask
						cd "${wd}" # wd defined in 'dir_change'
					else # Edit masks with whole brain mask
						edit_masks "${brain_master}" "${m_val}" "${edit_mask_dir}" &
						control_bg_jobs
					fi # if [ -z "${brain_master}" ]
				done # for j in ${!m_vals[@]}
			fi # if [ "${#m_vals[@]}" -gt '0' ]
		fi # if [ "${#check_complete_dir[@]}" -eq '0' ]
		
		wait # Wait for background processes to finish
		if ! [ -z "${brain_master}" ] && [ "${include_brain}" == 'yes' 2>/dev/null ]; then
			all_masks=($(printf "%s${IFS}" "${brain_master}" ${m_vals[@]})) # include whole brain mask by default
		else # Do not inclue whole brain mask
			all_masks=($(printf "%s${IFS}" ${m_vals[@]})) # raw mask values only
		fi
		
		# Beta extract files
		for j in ${!all_masks[@]}; do
			in_mask="${all_masks[${j}]}"
			
			if ! [ -z "${brain_master}" ] && [ "${in_mask}" == "${brain_master}" 2>/dev/null ]; then
				edit_mask="${brain_master}" # Whole brain has different naming convention
			else
				edit_mask="${edit_mask_dir}/"$(basename "${in_mask%.nii*}")"${output_edit_name}.nii.gz"
			fi
			
			if [ -f "${edit_mask}" ]; then
				base_mask=$(basename "${edit_mask%.nii*}" |sed "s/${output_edit_name}$//g")
				mask_beta_dir="${out_dir}/${output_beta_dir}/${base_mask}"
				
				if ! [ -d "${mask_beta_dir}" ]; then
					mkdir -p "${mask_beta_dir}" || vital_error_loop "${mask_beta_dir}" "${LINENO}"
				fi

				file_count=$((${file_count} + 1))
						
				out_beta="${mask_beta_dir}/${beta_out_head}_${base_mask}${out_ext}"
				echo "${ora}[${gre}${file_count}${ora}/${gre}${total_extractions}${ora}] ${pur}CREATING: ${ora}${out_beta}${whi}"
				mean_betas "${pe_file}" "${edit_mask}" "${out_beta}" & # Process in background to speed processing
				control_bg_jobs
			fi # if [ -f "${edit_mask}" ]
		done # for j in ${!all_masks[@]}
	done # for i in ${!in_pes[@]}
fi # if [ "${remove_betas}" == 'yes' 2>/dev/null ]

exit_message 0