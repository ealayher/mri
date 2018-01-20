#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 12/31/2017 By: Evan Layher (1.0) (layher@psych.ucsb.edu)
# Revised: 01/19/2017 By: Evan Layher (1.1) Minor updates
#--------------------------------------------------------------------------------------#
# Create percent signal change volumes from parameter estimate files in FSL
# MUST SOURCE fsl.sh script before running
# ASSUMES STANDARD FSL NAMING CONVENTION OF DIRECTORIES and FILES
# Run this script with '-h' option to read full help message

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
mean_nifti='mean_func.nii.gz' # Nifti file of mean activity over time
peak_file_low='design.mat' # (lower-level) File with peak-to-peak height values
pe_head='pe' # Parameter estimate filename header
peak_tag='/PPheights'  # Used with grep to get line with height values

peak_file_high='design.lcon' # (higher-level) File with mean of lower-level heights
cope_head='cope' # cope folder header

nii_ext='.nii.gz' # Nifti file extension
feat_ext='.feat'
gfeat_ext='.gfeat'
feat_exts=("${feat_ext}" "${gfeat_ext}") # Only include FSL folders with these extensions

output_folder='percent_signal_change' # Save within FEAT directory
output_file_head='psc' # Output filename header

percent_scale='100' # '100' Convert value to percentage
verify_time='10' # (secs) Display settings before running (input -s to suppress)
cmd_fslmaths="${FSLDIR}/bin/fslmaths" # fslmaths command
#--------------------------- DEFAULT SETTINGS ------------------------------#
text_editors=('kwrite' 'kate' 'gedit' 'open -a /Applications/BBEdit.app' 'open') # GUI text editor commands in preference order

IFS_old="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (useful when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
usage () { # Help message: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: ${gre}FSL ${whi}create percent signal change NIFTI files
Creates files for every parameter estimate stats file within FEAT folder(s)
Creates output folder (${ora}${output_folder}${whi}) within main FEAT folder
    
${ora}ADVICE${whi}: Create alias in ${ora}${HOME}/.bashrc${whi}
(e.g. ${gre}alias psc='${script_path}'${whi})
     
${ora}USAGE${whi}: Input lower and/or higher-level FEAT folder(s)
 [${ora}1${whi}] ${gre}psc ${ora}feat1.feat feat2.feat gfeat1.gfeat${whi}
     
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-cs${whi}  Prevent clearing screen at start
 ${pur}-f${whi}   Overwrite existing files
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-p${whi}   Specify which parameter estimate files to run
 [${ora}2${whi}] ${gre}psc ${ora}feat1.feat feat2.feat gfeat1.gfeat ${pur}-p ${ora}1 3 6${whi}
 ${pur}-s${whi}   Suppress startup message and run script immediately
     
${ora}VERSION: ${gre}${version}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm
} # usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version='1.1' # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
force_overwrite='no'  # 'no' : Do not overwrite files    [INPUT: '-f']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')
suppress_msg='no'     # 'no' : Do NOT verify parameters  [INPUT: '-s']

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate user inputs
	if [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-f' 2>/dev/null ] || \
	   [ "${1}" == '-h' 2>/dev/null ] || [ "${1}" == '--help' 2>/dev/null ] || \
	   [ "${1}" == '-nc' 2>/dev/null ] || [ "${1}" == '-nm' 2>/dev/null ] || \
	   [ "${1}" == '-o' 2>/dev/null ] || [ "${1}" == '--open' 2>/dev/null ] || \
	   [ "${1}" == '-p' 2>/dev/null ] || [ "${1}" == '-s' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ -d "${1}" ] || [ -L "${1}" ]; then # Gather valid FEAT folders (defined in 'feat_exts' array)
		check_feat_path=($(echo "${1}" |grep -E $(printf "%s${IFS}" ${feat_exts[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
		if [ "${#check_feat_path[@]}" -eq '0' ]; then
			bad_inputs+=("INVALID-FEAT-EXTENSIONS:${1}")
		else
			feat_dirs+=($(mac_readlink "${1}"))
		fi
	elif [ "${p_in}" == 'yes' 2>/dev/null ]; then # Specify pe or cope files
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -gt '0' 2>/dev/null ]; then
			p_vals+=("${1}")
		else
			bad_inputs+=("MUST-INPUT-INTEGER_-p:${1}")
		fi
	elif [ "${1:0:1}" == '-' 2>/dev/null ]; then # Invalid option
		bad_inputs+=("INVALID-OPTION:${1}")
	else # Invalid input
		bad_inputs+=("${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	p_in='no'  # [-p] pe or cope number(s)
	
	if [ "${1}" == '-cs' ]; then
		clear_screen='no'     # Do NOT clear screen at start
	elif [ "${1}" == '-f' ]; then
		force_overwrite='yes' # Overwrite files
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'   # Display help message
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no'  # Do NOT display messages in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'     # Do NOT display exit message
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'     # Open this script
	elif [ "${1}" == '-p' ]; then
		p_in='yes'		      # Read in user input (p-value(s))
	elif [ "${1}" == '-s' ]; then
		suppress_msg='yes'    # Do NOT display parameter verification message at start
	else # if option is undefined (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

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

create_psc_file () { # Create percent signal change file
	if ! [ -f "${mean_file}" ]; then # Mean activity file
		echo "${red}MISSING FILE: ${ora}${mean_file}${whi}"
		continue
	fi
	
	if ! [ -d "${out_dir}" ]; then
		mkdir "${out_dir}" # Create folder
	fi

	cd "${main_dir}" # Avoid FSL filepath whitespace errors
	
	# Create percent signal change file
	"${cmd_fslmaths}" "${rel_pe_file}" -mul "${percent_scale}" -mul "${peak_scale}" -div "${mean_nifti}" "${rel_out_file}"
	if [ -f "${rel_out_file}" ]; then
		echo "${gre}CREATED: ${ora}${final_out_file}${whi}"
	else
		echo "${red}NOT CREATED: ${ora}${final_out_file}${whi}"
	fi

	cd "${wd}" # cd back to working directory
} # create_psc_file

display_values () { # Display output with numbers
	if [ "${#@}" -gt '0' ]; then
		val_count=($(seq 1 1 ${#@}))
		vals_and_count=($(paste -d "${IFS}" <(printf "%s${IFS}" ${val_count[@]}) <(printf "%s${IFS}" ${@})))
		printf "${pur}[${ora}%s${pur}] ${gre}%s${IFS}${whi}" ${vals_and_count[@]}
	fi
} # display values

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
			exit_message 99 -nh -nm
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
		exit_message 98 -nh -nm
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

invalid_msg () { # Displays invalid input message
	clear
	echo "${red}INVALID INPUT:${whi}"
	printf "${ora}%s${IFS}${whi}" ${@}
} # invalid_msg

#---------------------------------- CODE -----------------------------------#
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

if [ "${#feat_exts[@]}" -eq '0' ]; then
	echo "${red}ARRAY MUST HAVE AT LEAST 1 VALUE${whi}"
	echo "${ora}feat_exts:${gre}${#feat_exts[@]}${whi}"
	exit_message 1 -nm
else # Sort unique values
	feat_exts=($(printf "%s${IFS}" ${feat_exts[@]} |sort -u))
fi

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
fi

# Exit script if invalid inputs
if [ "${#bad_inputs[@]}" -gt '0' ]; then
	invalid_msg ${bad_inputs[@]}
	exit_message 2
elif [ "${#feat_dirs[@]}" -eq '0' ]; then
	echo "${red}INPUT FEAT FOLDER(S) WITH THE FOLLOWING EXTENSIONS:${whi}"
	display_values ${feat_exts[@]}
	exit_message 3
elif [ -z "${FSLDIR}" ]; then # Check $FSLDIR
	echo "${red}UNDEFINED VARIABLE: ${ora}\$FSLDIR ${pur}(${ora}source '${gre}fsl.sh${ora}' script${pur})${whi}"
	exit_message 4 -nm
fi

vital_file "${cmd_fslmaths}"

for i in ${!feat_dirs[@]}; do # Loop thru input FEAT folders
	feat_dir="${feat_dirs[${i}]}" # FEAT folder
	pe_files+=($(find "${feat_dir}" -type f -name "${pe_head}[0-9]*${nii_ext}")) # Gather pe files
done # for i in ${!feat_dirs[@]}

# Separate lower-level and higher-level pe files (different calculations
pe_high_files=($(printf "%s${IFS}" ${pe_files[@]} |grep "/${cope_head}[0-9]*${feat_ext}/" |sort -u))
pe_low_files=($(printf "%s${IFS}" ${pe_files[@]} |grep -v "/${cope_head}[0-9]*${feat_ext}/" |sort -u))

if [ "${#p_vals[@]}" -gt '0' ]; then
	cope_filter=$(printf "/${cope_head}%s${feat_ext}/${IFS}" ${p_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')
	pe_filter=$(printf "${pe_head}%s${nii_ext}\$${IFS}" ${p_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')
	pe_high_files=($(printf "%s${IFS}" ${pe_high_files[@]} |grep -E "${cope_filter}"))
	pe_low_files=($(printf "%s${IFS}" ${pe_low_files[@]} |grep -E "${pe_filter}"))
fi # if [ "${#p_vals[@]}" -gt '0' ]

if [ "${#pe_low_files[@]}" -eq '0' ] && [ "${#pe_high_files[@]}" -eq '0' ]; then
	echo "${red}NO PARAMETER ESTIMATE FILES FOUND${whi}:"
	display_values ${feat_dirs[@]}
	
	if [ "${#p_vals[@]}" -gt '0' ]; then
		echo "${ora}SPECIFIED PARAMETER ESTIMATE FILES${whi}:"
		display_values ${p_vals[@]}
	fi
	exit_message 5
fi # [ "${#pe_low_files[@]}" -eq '0' ] && [ "${#pe_high_files[@]}" -eq '0' ]

# Alert user of parameters before running (-s to suppress)
if ! [ "${suppress_msg}" == 'yes' 2>/dev/null ]; then
	if ! [ "${verify_time}" -ge '1' 2>/dev/null ]; then
		verify_time='1' # Default to '1' to avoid errors
	fi
	
	display_values ${pe_high_files[@]} ${pe_low_files[@]}
	
	echo "${ora}INPUT ${gre}ctrl${ora}+${gre}c ${ora}TO CRASH${whi}"
	printf "${ora}STARTING IN: ${whi}"
	for i in $(seq "${verify_time}" -1 1); do # Loop thru seconds
		printf "${pur}${i} ${whi}" # Display number of seconds before processing
		sleep 1 # Wait 1 second
	done
fi # if ! [ "${suppress_msg}" == 'yes' 2>/dev/null ]
echo "${ora}PROCESSING: ${gre}"$((${#pe_high_files[@]} + ${#pe_low_files[@]}))" ${ora}PARAMETER ESTIMATE FILE(S)${whi}" # Alert user of script start

wd=$(pwd) # Working directory
for i in ${!pe_high_files[@]}; do # Loop thru higher level pe files
	pe_high_file="${pe_high_files[${i}]}" # pe file
	main_dir=$(dirname $(dirname "${pe_high_file}")) # cope.feat folder
	rel_pe_file=$(echo "${pe_high_file}" |sed "s@^${main_dir}/@@g") # Relative pe filepath
	
	peak_file="${main_dir}/${peak_file_high}" # Contains single peak value (lower-level peak-to-peak average)
	mean_file="${main_dir}/${mean_nifti}" # Mean activity at each voxel

	out_file_num=$(basename "${main_dir}" |sed -e "s@${cope_head}@@g" -e "s@${feat_ext}@@g") # Number only
	out_file="${output_file_head}${out_file_num}${nii_ext}"
	rel_out_file="${output_folder}/${out_file}" # Relative path
	out_dir="${main_dir}/${output_folder}"
	final_out_file="${out_dir}/${out_file}"
	
	if [ -f "${peak_file}" ]; then # Get peak value
		check_peak_scale=($(<"${peak_file}")) # Single scalar value
		if [ "${#check_peak_scale[@]}" -eq '1' ]; then
			peak_scale="${check_peak_scale[0]}"
		else # Should only be 1 value
			echo "${red}INVALID PEAK VALUE:${whi}"
			display_values ${check_peak_scale[@]}
			echo "${red}PEAK FILE: ${ora}${peak_file}${whi}"
			continue
		fi # if [ "${#check_peak_scale[@]}" -eq '1' ]
	else # Must obtain peak value from "${peak_file}"
		echo "${red}MISSING FILE: ${ora}${peak_file}${whi}"
		continue
	fi # if [ -f "${peak_file}" ]
	
	create_psc_file
done

for i in ${!pe_low_files[@]}; do # Loop thru lower level pe files
	pe_low_file="${pe_low_files[${i}]}"

	main_dir=$(dirname $(dirname "${pe_low_file}")) # Main FEAT folder
	rel_pe_file=$(echo "${pe_low_file}" |sed "s@^${main_dir}/@@g") # Relative pe filepath
	
	peak_file="${main_dir}/${peak_file_low}" # Contains peak-to-peak value for each pe
	mean_file="${main_dir}/${mean_nifti}" # Mean activity at each voxel

	out_file_num=$(basename "${pe_low_file}" |sed -e "s@${pe_head}@@g" -e "s@${nii_ext}@@g") # Number only
	out_file="${output_file_head}${out_file_num}${nii_ext}"
	rel_out_file="${output_folder}/${out_file}" # Relative path
	out_dir="${main_dir}/${output_folder}"
	final_out_file="${out_dir}/${out_file}"
	
	if [ -f "${peak_file}" ]; then # Get peak value
		check_peak_scale=($(grep "${peak_tag}" "${peak_file}" |awk -v var=$((${out_file_num} + 1)) '{print $var}')) # Column + 1
		if [ "${#check_peak_scale[@]}" -eq '1' ]; then
			peak_scale="${check_peak_scale[0]}"
		else # Should only be 1 value
			echo "${red}INVALID PEAK VALUE:${whi}"
			display_values ${check_peak_scale[@]}
			echo "${red}PEAK FILE: ${ora}${peak_file}${whi}"
			continue
		fi # if [ "${#check_peak_scale[@]}" -eq '1' ]
	else # Must obtain peak value from "${peak_file}"
		echo "${red}MISSING FILE: ${ora}${peak_file}${whi}"
		continue
	fi # if [ -f "${peak_file}" ]
	
	create_psc_file
done

exit_message 0