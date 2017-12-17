#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 05/29/2014 By: Evan Layher (layher@psych.ucsb.edu)
# Revised: 12/13/2014 By: Evan Layher # (1.1)
# Revised: 09/08/2015 By: Evan Layher # (2.0) Cleaner, faster and more versatile
# Revised: 01/25/2017 By: Evan Layher # (3.0) Mac and Linux compatible + minor updates
# Revised: 04/22/2017 By: Evan Layher # (3.1) minor updates
# Revised: 12/16/2017 By: Evan Layher # (3.2) minor updates
#--------------------------------------------------------------------------------------#
# Correct for fMRI multiple comparisons with gaussian random field (GRF) statistics using FSL's 'cluster' function
# http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Cluster
# MUST SOURCE fsl.sh script before running
# ASSUMES STANDARD FSL NAMING CONVENTION OF DIRECTORIES and FILES
# Run this script with '-h' option to read full help message

## --- LICENSE INFORMATION --- ##
## cluster_grf.sh is the proprietary property of The Regents of the University of California ("The Regents.")

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
default_t=('3.1')     # ('3.1'): Can place multiple values e.g. ('2.3' '3.1') 
default_p=('0.05')    # ('0.05'): Can place multiple values e.g. ('0.05' '0.01')
nifti_stats=('zstat') # ('zstat') Type of nifti stat file(s) to cluster correct inside FEAT 'stats' folder e.g. ('tstat' 'zstat')
default_masks=()      # () is no folders/files; otherwise e.g. ('examplepath1/maskDir' 'examplepath2/maskDir')

feat_exts=('.feat' '.gfeat') # ('.feat' '.gfeat'): Only include FSL folders with these extensions
mask_exts=('.nii.gz')        # ('.nii.gz'): Only include structural masks with these extensions
stat_exts=('.nii.gz')        # ('.nii.gz'): Stat file extensions for single file input
whole_brain_mask='mask.nii.gz'     # mask.nii.gz: Name of group-level whole brain mask found in cope.feat folder
whole_brain_output='brain'         # Output folder of whole brain cluster corrected results

output_cluster_dir='cluster_grf' # Folder that will contain cluster output files in each cope.feat folder
output_mask_edits='mask_edits'   # Folder that will contain edited masks in ${output_cluster_dir}
output_edit_name='_edit'         # Mask edit filename attached to mask file
pos_neg=('pos' 'neg')       # Filename ending for positive and negative stat values respectively

wait_time='10' # Number of seconds to wait if "-f" option used

# FSL default values
feat_stats_ext='.nii.gz' # FSL stat file extension
group_feat_ext='.gfeat'  # FSL group FEAT output folder extension
feat_stats_dir='stats'   # FSL stats folder within '.feat'
cope_dir_name='cope'     # FSL 'cope' : copeX.feat folder name
cope_dir_ext='.feat'     # FSL '.feat': copeX.feat extension name
#--------------------------- DEFAULT SETTINGS ------------------------------#
max_bg_jobs='5' # Maximum number of background processes (1-10)
text_editors=('kwrite' 'kate' 'gedit' 'open -a /Applications/BBEdit.app' 'open') # GUI text editor commands in preference order

IFS_old="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (useful when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
usage () { # Help message: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: FSL '${gre}cluster${whi}' using Gaussian Random Field (GRF) statistics
 Perform '${gre}cluster${whi}' on FSL fMRI stat files to correct for multiple comparisons
 ${pur}DEFAULT${whi} : whole brain cluster correction
 ${pur}OPTIONAL${whi}: input structural mask(s) for smaller volume correction
 ${red}ASSUMES STANDARD FSL NAMING CONVENTION OF (G)FEAT FOLDERS AND FILES${whi}
 
${ora}OUTPUT FOLDERS WITHIN DESIRED FEAT FOLDER(S) UNLESS SPECIFIED WITH ${pur}-out${ora} OPTION${whi}: 
 [${pur}1${whi}] ${gre}${output_cluster_dir}${whi} # Main Folder
 
 # Masks are edited with each FEAT brain ${ora}${whole_brain_mask} ${whi}to remove empty voxels
 [${pur}2${whi}] ${gre}${output_cluster_dir}/${output_mask_edits}${whi}

 # Each input mask (and ${ora}${whole_brain_output}${whi}) has a folder containing cluster files
 [${pur}3${whi}] ${gre}${output_cluster_dir}/${ora}MASK_NAME${whi}
 
${ora}OUTPUT FILE(S)${whi}: (${pur}NAMING CONVENTION EXAMPLE: ${ora}zstat1_brain_t2.3_p0.05_grf${whi})
 ${red}NOTE: ${ora}OUTPUTS BOTH POSITIVE AND NEGATIVE THRESHOLDING FILES${whi}
 [${pur}1${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf.nii.gz${whi} # Thresholded cluster corrected file
 [${pur}2${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf_${pur}${pos_neg[1]}${gre}.nii.gz${whi} # Negative corrected file
 [${pur}3${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf_${pur}${pos_neg[0]}${gre}.nii.gz${whi} # Positive corrected file
 [${pur}4-5${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf_${pur}${pos_neg[1]}${gre}_idx.nii.gz${whi} # Index of cluster(s)
 [${pur}6-7${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf_${pur}${pos_neg[0]}${gre}_clusters.txt${whi} # Cluster information
 [${pur}8-9${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf_${pur}${pos_neg[1]}${gre}_lmax.txt${whi} # Local maxima per cluster
 [${pur}10+${whi}] ${ora}zstat1_brain_t2.3_p0.05_grf_${pur}${pos_neg[0]}${gre}_idx_${red}X${gre}.nii.gz${whi} # Individual cluster mask
 
 ${ora}IF ${red}NO SIGNIFICANT ${ora}RESULTS FOUND${whi}
 [${pur}1-2${whi}] ${ora}zstat1_brain_t2.3_p0.05_${pur}${pos_neg[1]}${red}_none.nii.gz${whi} # Empty file
 [${pur}3-4${whi}] ${ora}zstat1_brain_t2.3_p0.05_${pur}${pos_neg[0]}${red}_none.txt${whi} # Parameter information
 
 ${ora}IF ${red}ERROR ${ora}OCCURS${whi}
 [${pur}1${whi}] ${ora}zstat1_brain_t2.3_p0.05${red}_invalid.txt${whi}
     
${ora}ADVICE${whi}: Create an alias inside your ${ora}${HOME}/.bashrc${whi} file
(e.g. ${gre}alias grf='${script_path}'${whi})
     
${ora}USAGE${whi}: 
 ${pur}Inputs${whi}: [${ora}1${whi}] None [${ora}2${whi}] text file [${ora}3${whi}] (G)FEAT folder(s) 
 [${ora}1${whi}] ${gre}grf${whi} # Searches working directory for (G)FEAT folders
 [${ora}2${whi}] ${gre}grf ${ora}feat_paths.txt${whi} # Use (G)FEAT folders listed in file
 [${ora}3${whi}] ${gre}grf ${ora}sub1.feat group.gfeat${whi} # Use (G)FEAT input
 
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-c${whi}   Only use specific '${ora}cope${red}X${ora}.feat${whi}' inputs within GFEAT folder(s)
 [${ora}4${whi}] ${gre}grf ${ora}gfeat_list.txt ${pur}-c ${ora}1 2 5${whi} # cope1.feat, cope2.feat, cope5.feat
 
 ${pur}-cs${whi}  Prevent screen from clearing before script processes
 ${pur}-f${whi}   Force file creation without prompting after ${gre}${wait_time}${whi} seconds
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-m${whi} or ${pur}-mask${whi}   Input structural mask(s) to confine cluster correction
 [${ora}5${whi}] ${gre}grf ${ora}group.gfeat ${pur}-m ${ora}L_DLPFC.nii.gz R_DLPFC.nii.gz${whi}
 
 ${pur}-nb${whi}  Do ${red}NOT ${whi}automatically include whole brain mask
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-nt${whi}  Prevent script process time from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-out${whi} or ${pur}-output${whi} Specify output folder for all output files
 [${ora}6${whi}] ${gre}grf ${ora}group.gfeat ${pur}-output ${ora}~/Desktop ${whi}# Output all files on Desktop
 
 ${pur}-p${whi}   Specify clusterwise p-value(s) (${ora}0${whi} to ${ora}1${whi})
 [${ora}7${whi}] ${gre}grf ${ora}sub1.feat ${pur}-p ${ora}0.01 0.05${whi}
 
 ${pur}-rm${whi}  Remove unwanted cluster files generated by this script
 [${ora}8${whi}] ${gre}grf ${ora}gfeat_list.txt ${pur}-m ${ora}L_DLPFC.nii.gz ${pur}-rm${whi} # Remove files from 'L_DLPFC' mask
   ${red}REMOVE OPTIONS:${pur}-rm ${red}MUST BE LAST INPUT${whi}
   [${pur}1${whi}] ${pur}all${whi} or ${pur}-all${whi} Remove ${red}ALL${whi} cluster files in FEAT/GFEAT folder(s)
 [${ora}9${whi}] ${gre}grf ${ora}gfeat_list.txt ${pur}-rm all${whi}
  
   [${pur}2${whi}] ${pur}allp${whi} or ${pur}-allp${whi} Remove ${red}ALL ${whi}clusterwise p-values in cluster files
 [${ora}10${whi}] ${gre}grf ${pur}-t ${ora}2.3 ${pur}-rm allp${whi} # Remove all p-values with 2.3 threshold
 
   [${pur}3${whi}] ${pur}allt${whi} or ${pur}-allt${whi} Remove ${red}ALL ${whi}threshold values in cluster files
 [${ora}11${whi}] ${gre}grf ${pur}-p ${ora}0.01 ${pur}-rm allt${whi} # Remove all threshold values with p=0.01
 
   [${pur}4${whi}] ${pur}except${whi} or ${pur}-except${whi} Remove ${red}ALL${whi} stat files ${red}EXCEPT ${whi}specified files
 [${ora}12${whi}] ${gre}grf ${pur}-t ${ora}2.3 ${pur}-rm except${whi} # Save cluster files with 2.3 threshold
 
  ${pur}-s${whi}   Specify '${ora}stat${whi}' file number(s)
 [${ora}13${whi}] ${gre}grf ${ora}gfeat_list.txt ${pur}-s ${ora}1 2${whi} # zstat1.nii.gz, zstat2.nii.gz
 
 ${pur}-t${whi} or ${pur}-z${whi} Specify threshold value(s): ${red}AT ${whi}and ${red}ABOVE${whi} input
 [${ora}14${whi}] ${gre}grf ${ora}gfeat_list.txt ${pur}-t ${ora}2.3 3.1${whi}
 
${ora}DEFAULT SETTINGS${whi}: Defined in script
p-value(s): 
${gre}${default_p[@]}${whi}
 
stat file(s): 
${gre}${nifti_stats[@]}${whi}
 
t-value(s): 
${gre}${default_t[@]}${whi}

${ora}REFERENCE${whi}: ${gre}http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Cluster${whi}
     
${ora}VERSION: ${gre}${version}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm -nt
} # usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
start_time=$(date +%s) # Time in seconds
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version='3.2' # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
force_create='no'     # 'no' : Create files w/o prompts  [INPUT: '-f']
include_brain='yes'   # 'yes': Include whole brain       [INPUT: '-nb']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
remove_all_p='no'	  # 'no' : Remove all p-value files  [INPUT: '-rm ap']
read_feat_dir='yes'	  # 'yes': First inputs should be specified feat folders or stat files
remove_all_stats='no' # 'no' : Remove all stat files     [INPUT: '-rm a']
remove_all_t='no'	  # 'no' : Remove all t-value files  [INPUT: '-rm at']
remove_clusters='no'  # 'no' : Removes cluster files     [INPUT: '-rm']
remove_exception='no' # 'no' : Removal all stats except..[INPUT: '-rm e']
show_time='yes'       # 'yes': Display process time      [INPUT: '-nt']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate user inputs
	if [ "${1}" == '-c' 2>/dev/null ] || [ "${1}" == '-cs' 2>/dev/null ] || \
	   [ "${1}" == '-f' 2>/dev/null ] ||  [ "${1}" == '-h' 2>/dev/null ] || \
	   [ "${1}" == '--help' 2>/dev/null ] || [ "${1}" == '-m' 2>/dev/null ] || \
	   [ "${1}" == '-mask' 2>/dev/null ] || [ "${1}" == '-nb' 2>/dev/null ] || \
	   [ "${1}" == '-nc' 2>/dev/null ] || [ "${1}" == '-nt' 2>/dev/null ] || \
	   [ "${1}" == '-nm' 2>/dev/null ] || [ "${1}" == '-o' 2>/dev/null ] || \
	   [ "${1}" == '--open' 2>/dev/null ] || [ "${1}" == '-p' 2>/dev/null ] || \
	   [ "${1}" == '-out' 2>/dev/null ] || [ "${1}" == '-output' 2>/dev/null ] || \
	   [ "${1}" == '-rm' 2>/dev/null ] || [ "${1}" == '-s' 2>/dev/null ] || \
	   [ "${1}" == '-t' 2>/dev/null ] || [ "${1}" == '-z' 2>/dev/null ]; then
		read_feat_dir='no' # Do not search for FEAT directories
		activate_options "${1}"
	elif [ "${read_feat_dir}" == 'yes' 2>/dev/null ]; then
		if [ -f "${1}" ]; then # If list of feat directories or single file input
			skip_feat='no' # Reset value (check for FEAT folder)
			check_stat=($(echo "${1}" |grep -E $(printf "%s\$${IFS}" ${stat_exts[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
			if [ "${#check_stat[@]}" -gt '0' ]; then
				stat_inputs+=($(mac_readlink "${1}"))
				skip_feat='yes'
				continue
			fi
			
			if [ "${skip_feat}" == 'no' 2>/dev/null ]; then # Search for FEAT folders
				check_feat_paths=($(cat "${1}" 2>/dev/null |grep -E $(printf "%s\$${IFS}" ${feat_exts[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
				if [ "${#check_feat_paths[@]}" -eq '0' ]; then
					bad_inputs+=("input_file:${1}")
				else # Gather existing FEAT directories from files
					for i in ${!check_feat_paths[@]}; do
						check_feat_path="${check_feat_paths[${i}]}"
						if [ -d "${check_feat_path}" ] || [ -L "${check_feat_path}" ]; then
							feat_dirs+=($(mac_readlink "${check_feat_path}"))
						else
							bad_inputs+=("missing_feat_folder:${check_feat_path}")
						fi
					done # for i in ${!check_feat_paths[@]}
				fi # if [ "${#check_feat_paths[@]}" -eq '0' ]
			fi # if [ "${skip_feat}" == 'no' 2>/dev/null ]
		elif [ -d "${1}" ] || [ -L "${1}" ]; then # Gather valid FEAT folders (defined in 'feat_exts' array)
			check_feat_path=($(echo "${1}" |grep -E $(printf "%s${IFS}" ${feat_exts[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
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
		check_struc_masks $(mac_readlink "${1}") # Cluster correct with structural mask
	elif [ "${o_in}" == 'yes' 2>/dev/null ]; then # Use specified output folder
		o_in='no' # Reset value
		if [ -d "${1}" ] || [ -L "${1}" ]; then
			output_folder+=($(mac_readlink "${1}"))
		else
			bad_inputs+=("invalid_output_folder:${1}")
		fi
	elif [ "${p_in}" == 'yes' 2>/dev/null ]; then # Use p-value threshold
		check_p_values "${1}" # Decimal from 0 to 1
		p_vals+=("${1}")
	elif [ "${rm_in}" == 'yes' 2>/dev/null ]; then # Remove unwanted cluster corrected files
		if [ "${1}" == 'all' ] || [ "${1}" == '-all' ]; then
			remove_all_stats='yes' # Remove all values
		elif [ "${1}" == 'allp' ] || [ "${1}" == '-allp' ]; then
			remove_all_p='yes' # Remove all p-values (useful when default_p is defined)
		elif [ "${1}" == 'allt' ] || [ "${1}" == '-allt' ]; then
			remove_all_t='yes' # Remove all t-values (useful when default_t is defined)
		elif [ "${1}" == 'except' ] || [ "${1}" == '-except' ]; then
			remove_exception='yes' # Remove all files except those specified
		else
			bad_inputs+=("-rm:${1}")
		fi
	elif [ "${s_in}" == 'yes' 2>/dev/null ]; then
		check_natural_num "${1}" # Must be whole number > '0'
		s_vals+=("${1}") # Which stat file numbers to use
	elif [ "${t_in}" == 'yes' 2>/dev/null ]; then
		check_t_values "${1}" # t-value threshold values (positive or negative values)
		t_vals+=("${1}") # NOTE: Thresholding occurs at or above values (negative values will allow all positive results)
	else # invalid input
		bad_inputs+=("${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	c_in='no'  # [-c] copeX.feat folder values (whole number greater than 0)
	m_in='no'  # [-m] structural mask (full path to mask file)
	o_in='no'  # [-out, -output] Output folder for stat input file(s)
	p_in='no'  # [-p] p-value (from 0 to 1)
	rm_in='no' # [-rm] read in remove options
	s_in='no'  # [-s] stat numbers (e.g. zstat1.nii.gz) (whole number greater than 0)
	t_in='no'  # [-t] t-value threshold (number)

	if [ "${1}" == '-c' ]; then
		c_in='yes' 		      # Read in user input (cope number(s))
	elif [ "${1}" == '-cs' ]; then
		clear_screen='no'	  # Do not clear screen
	elif [ "${1}" == '-f' ]; then
		force_create='yes'    # Create files without prompting
		if [ -z "${wait_time}" ] || ! [ "${wait_time}" -eq "${wait_time}" 2>/dev/null ]; then
			bad_inputs+=("NON-INTEGER_VARIABLE_WITHIN_SCRIPT:wait_time:-f")
		fi # Integer needed for 'seq' command
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'	  # Display help message
	elif [ "${1}" == '-m' ] || [ "${1}" == '-mask' ]; then
		m_in='yes'            # Read in user input (mask file(s))
	elif [ "${1}" == '-nb' ]; then
		include_brain='no'    # Do NOT include whole brain
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no'  # Do not display in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'	  # Do not display exit message
	elif [ "${1}" == '-nt' ]; then
		show_time='no'		  # Do not display script process time
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'	  # Open this script
	elif [ "${1}" == '-out' ] || [ "${1}" == '-output' ]; then
		o_in='yes'	          # Read in output folder
	elif [ "${1}" == '-p' ]; then
		p_in='yes'		      # Read in user input (p-value(s))
	elif [ "${1}" == '-rm' ]; then
		rm_in='yes'		      # Read in user input (remove values)
		remove_clusters='yes' # Remove cluster files
	elif [ "${1}" == '-s' ]; then
		s_in='yes'		      # Read in user input (stat file number(s))
	elif [ "${1}" == '-t' ] || [ "${1}" == '-z' ]; then
		t_in='yes'		      # Read in user input (thresholding value(s))
	else # if option is undefined (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

check_bad_inputs () { # Exit script if bad inputs found
	if [ "${#bad_inputs[@]}" -gt '0' ]; then
		invalid_msg ${bad_inputs[@]}
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

check_p_values () { # check p-values are in appropriate range 0 to 1
	for i_check_p_values in ${@}; do
		check_valid_p=$(echo |awk -v var="${i_check_p_values}" '{print (var >= 0 && var <= 1)}')
		if [ "${check_valid_p}" -eq '0' ]; then # Returns 1 if valid, 0 if invalid
			bad_inputs+=("p-value:${i_check_p_values}")
		fi
	done
} # check_p_values

check_struc_masks () { # Confirms valid mask file or searches directory for mask files
	for i_check_struc_masks in ${@}; do
		check_masks=() # Reset check_masks array
		if [ -f "${i_check_struc_masks}" ]; then
			check_mask=($(mac_readlink "${i_check_struc_masks}" |grep -E $(printf "%s${IFS}" ${mask_exts[@]} |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//')))
			if [ "${#check_mask[@]}" -eq '0' ]; then
				bad_inputs+=("invalid_mask_extension:${i_check_struc_masks}")
			else
				m_vals+=("${check_mask[0]}")
			fi
		elif [ -d "${i_check_struc_masks}" ]; then
			for j in ${!mask_exts[@]}; do
				mask_ext=$(echo "${mask_exts[${j}]}" |sed 's@\.@\\.@g')
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

check_t_values () { # check t-values are between -1000000 and 1000000 (arbitrarily large range)
	for i_check_p_values in ${@}; do
		check_valid_t=$(echo |awk -v var="${i_check_p_values}" '{print (var > -1000000 && var < 1000000)}')
		if [ "${check_valid_t}" -eq '0' ]; then # Returns 1 if valid, 0 if invalid
			bad_inputs+=("t-value:${i_check_p_values}")
		fi
	done
} # check_t_values

cluster_func () { # GRF cluster correction

	run_cluster () { # Actual cluster function (run in function to get all output)
		echo 'CREATED:'$(date +%x" "%r)" BY:${script_path} ("$(whoami)')'
		echo "MASK:${mask_in} SMOOTHNESS:${dlh} VOXELS:${vol}"
		"${FSLDIR}/bin/cluster" \
		-i "${stat_out}" \
		-o "${stat_out}_idx" \
		--othresh="${stat_out}" \
		--olmax="${stat_out}_lmax.txt" \
		--minclustersize \
		--mm \
		-t "${t_val}" \
		-p "${p_val}" \
		-d "${dlh}" \
		--volume="${vol}"
	} # run_cluster
	
	dir_change "${out_dir}" # Avoid special characters in file path
	stat_in=$(echo "${1}" |sed "s@^${out_dir}/@@g") # Input stat file
	mask_in=$(echo "${2}" |sed "s@^${out_dir}/@@g") # Input mask file
	stat_out_temp=$(echo "${3}" |sed "s@^${out_dir}/@@g") # Output stat name

	dlh=$("${FSLDIR}/bin/smoothest" -m "${mask_in}" -z "${stat_in}" |awk '/DLH/ {print $2}')    # 'cluster' requires smoothness of stat files (within mask)
	vol=$("${FSLDIR}/bin/smoothest" -m "${mask_in}" -z "${stat_in}" |awk '/VOLUME/ {print $2}') # 'cluster' requires volume of stat files (within mask)
	check_dlh=$(echo |awk -v var="${dlh}" '{print (var > 0)}') # Make sure value > 0 (0 = no, 1 = yes)
	check_vol=$(echo |awk -v var="${vol}" '{print (var > 0)}') # Make sure value > 0 (0 = no, 1 = yes)
	
	if [ "${check_dlh}" -eq '1' 2>/dev/null ] && [ "${check_vol}" -eq '1' 2>/dev/null ]; then
		combine_files=() # Reset array
		for i_cluster_func in ${!pos_neg[@]}; do
			pos_or_neg="${pos_neg[${i_cluster_func}]}"
			stat_out="${stat_out_temp}_${pos_or_neg}"
			
			if [ "${i_cluster_func}" -eq '0' ]; then # positive value
				"${FSLDIR}/bin/fslmaths" "${stat_in}" -mas "${mask_in}" "${stat_out}" || vital_error_loop "${stat_out}" "${LINENO}" # Mask stat file or exit loop (if error)
				run_cluster > "${stat_out}_clusters.txt" # 'run_cluster prints all desired output
			else
				"${FSLDIR}/bin/fslmaths" "${stat_in}" -mas "${mask_in}" "${stat_out}" || vital_error_loop "${stat_out}" "${LINENO}" # Mask stat file or exit loop (if error)
				"${FSLDIR}/bin/fslmaths" "${stat_out}" -mul -1 "${stat_out}" # Change negative to positive
				run_cluster > "${stat_out}_clusters.txt" # 'run_cluster prints all desired output
				"${FSLDIR}/bin/fslmaths" "${stat_out}" -mul -1 "${stat_out}" # Change back to negative
			fi

			check_empty=($("${FSLDIR}/bin/fslstats" "${stat_out}" -V |awk '{print $1}')) # Checks for empty clusters
			if [ "${check_empty[0]}" -eq '0' ]; then # Identify files with no significant clusters
				stat_none="${stat_out%_grf*}_${pos_or_neg}_none"
				mv "${stat_out}.nii.gz" "${stat_none}.nii.gz"    # Empty stat file
				mv "${stat_out}_clusters.txt" "${stat_none}.txt" # Good to see parameters used
				rm "${stat_out}"* # Remove all other stat files
			else # Create individual functional masks for each cluster
				total_idx_clusters=$("${FSLDIR}/bin/fslstats" "${stat_out}_idx.nii.gz" -R |awk '{print $2}') # Total clusters in mask
				for i_clus in $(seq 1 1 ${total_idx_clusters}); do # Creates individual cluster masks
					"${FSLDIR}/bin/fslmaths" -dt int "${stat_out}_idx.nii.gz" -thr "${i_clus}" -uthr "${i_clus}" "${stat_out}_idx_${i_clus}.nii.gz"
				done
				
				combine_files+=("${stat_out}")
			fi # if [ "${check_empty[0]}" -eq '0' ]
		done # for i_cluster_func in ${!pos_neg[@]}
		
		if [ "${#combine_files[@]}" -eq '1' ]; then # Significant in 1 direction only
			cp "${combine_files[0]}${feat_stats_ext}" "${stat_out_temp}${feat_stats_ext}"
		elif [ "${#combine_files[@]}" -eq '2' ]; then # Merge files
			"${FSLDIR}/bin/fslmaths" "${combine_files[0]}" -add "${combine_files[1]}" "${stat_out_temp}"
		fi
	else
		echo "${red}INVALID MASK (PROBABLY TOO SMALL): ${ora}${mask_in}${whi}"
		echo "INVALID MASK (PROBABLY TOO SMALL): ${mask_in}" > "${stat_out%_grf}_invalid.txt"
	fi # if [ "${dlh}" -eq "${dlh}" 2>/dev/null ] && [ "${vol}" -eq "${vol}" 2>/dev/null ]
	cd "${wd}"
} # cluster_func

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
			exit_message 98 -nh -nm -nt
		fi
	else # Missing input file
		echo "${red}MISSING FILE: ${ora}${open_file}${whi}"
	fi # if [ -f "${open_file}" ]; then
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

control_c () { # Function activates after 'ctrl + c'
	echo "${red}FINISHING CURRENT BACKGROUND PROCESSES BEFORE CRASHING${whi}"
	exit_message 96 -nm -nt
} # control_c

invalid_msg () { # Displays invalid input message
	clear
	echo "${red}INVALID INPUT:${whi}"
	printf "${ora}%s${IFS}${whi}" ${@}
} # invalid_msg

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

# Crash if essential arrays are empty
if [ "${#feat_exts[@]}" -eq '0' ] || [ "${#mask_exts[@]}" -eq '0' ] || \
   [ "${#nifti_stats[@]}" -eq '0' ] || [ "${#stat_exts[@]}" -eq '0' ]; then
	echo "${red}ARRAYS MUST HAVE AT LEAST 1 INPUT${whi}"
	echo "${ora}feat_exts:${gre}${#feat_exts[@]}${whi}"
	echo "${ora}mask_exts:${gre}${#mask_exts[@]}${whi}"
	echo "${ora}nifti_stats    :${gre}${#nifti_stats[@]}${whi}"
	echo "${ora}stat_exts:${gre}${#stat_exts[@]}${whi}"
	exit_message 1 -nm -nt
else # Sort unique values
	feat_exts=($(printf "%s${IFS}" ${feat_exts[@]} |sort -u))
	mask_exts=($(printf "%s${IFS}" ${mask_exts[@]} |sort -u))
	nifti_stats=($(printf "%s${IFS}" ${nifti_stats[@]} |sort -u))
	stat_exts=($(printf "%s${IFS}" ${stat_exts[@]} |sort -u))
fi

check_pos_neg=($(printf "%s${IFS}" ${pos_neg[@]} |sort -u))
if [ "${#check_pos_neg[@]}" -ne '2' ]; then
	echo "${red}ARRAY MUST HAVE 2 UNIQUE VALUES: ${ora}pos_neg:${whi}"
	display_values ${check_pos_neg[@]}
	exit_message 2 -nm -nt
fi

for inputs; do # Reads through all inputs
	option_eval "${inputs}"
done

if ! [ "${clear_screen}" == 'no' 2>/dev/null ]; then
	clear     # Clears screen unless activation of input option: '-cs'
fi

color_formats # Activates or inhibits colorful output

# Display help message or open script
if [ "${activate_help}" == 'yes' 2>/dev/null ]; then # '-h' or '--help'
	usage # Display help message
elif [ "${open_script}" == 'yes' 2>/dev/null ]; then # '-o' or '--open'
	open_text_editor "${script_path}" # Open script
	exit_message 0 -nm -nt
elif [ -z "${FSLDIR}" ]; then # Check $FSLDIR
	echo "${red}UNDEFINED VARIABLE: ${ora}\$FSLDIR ${pur}(${ora}source '${gre}fsl.sh${ora}' script${pur})${whi}"
	exit_message 3 -nm -nt
fi

#---------------- CHECK FOR VALID VALUES BEFORE PROCESSING -----------------#
check_bad_inputs
vital_file "${FSLDIR}/bin/cluster" "${FSLDIR}/bin/fslhd" "${FSLDIR}/bin/fslmaths" "${FSLDIR}/bin/fslstats" "${FSLDIR}/bin/smoothest"
echo "${ora}RUNNING: ${gre}${script_path}${whi}"

# Check FEAT directories
if [ "${#feat_dirs[@]}" -eq '0' ] && [ "${#stat_inputs[@]}" -eq '0' ]; then
	for i in ${!feat_exts[@]}; do # Get all feat directories in working directory
		feat_ext=$(echo "${feat_exts[${i}]}" |sed 's@\.@\\.@g')
		feat_dirs+=($(find "$(pwd)" -maxdepth 1 -name "*${feat_ext}" |grep -v "^$(pwd)$")) # Find in linked folders too
	done
fi

if [ "${#feat_dirs[@]}" -eq '0' ] && [ "${#stat_inputs[@]}" -eq '0' ]; then # Exit if no valid FEAT directories found
	echo "${red}NO FEAT FOLDERS FOUND WITH THE FOLLOWING EXTENSIONS:${whi}"
	display_values ${feat_exts[@]}
	exit_message 4 -nt
fi

if [ "${#output_folder[@]}" -eq '0' ]; then
	if [ "${#stat_inputs[@]}" -gt '0' ]; then
		final_output=$(pwd)
	fi
elif [ "${#output_folder[@]}" -eq '1' ]; then
	final_output="${output_folder[0]}"
else # Multiple output folders
	echo "${red}ONLY SPECIFY 1 OUTPUT FOLDER${whi}"
	display_values "${output_folder[@]}"
	exit_message 5 -nt
fi
	
# Check cope.feat directories
if [ "${#c_vals[@]}" -eq '0' ]; then # Which cope.feat directories to use
	c_vals=('^') # Used with 'grep -E' (gets all cope values)
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
elif [ "${#stat_inputs[@]}" -gt '0' ]; then
	echo "${red}MUST INPUT MASK FILE (${pur}-m${red}) WITH STAT FILE INPUT${whi}"
	exit_message 6 -nt
fi

# Check p-values
if [ "${#p_vals[@]}" -eq '0' ]; then
	p_vals=($(printf "%s${IFS}" ${default_p[@]}))
fi

# Remove trailing zeros/decimals and sort unique values
p_vals=($(printf "%s${IFS}" ${p_vals[@]} |sed -e 's/^0$/0.0/g' -e 's/0*$//g' -e 's/\.$//g' |sort -u))

# Check t-values
if [ "${#t_vals[@]}" -eq '0' ]; then
	t_vals=($(printf "%s${IFS}" ${default_t[@]}))
fi

# Remove trailing zeros/decimals and sort unique values
t_vals=($(printf "%s${IFS}" ${t_vals[@]} |sed -e 's/^0$/0.0/g' -e 's/0*$//g' -e 's/\.$//g' |sort -u))

if [ "${#p_vals[@]}" -eq '0' ] || [ "${#t_vals[@]}" -eq '0' ]; then
	echo "${red}MISSING ${ora}p ${red}or ${ora}t value(s)${red}:${whi}"
 	echo "${ora}p-values (${gre}${#p_vals[@]}${ora}):${whi}"
 	dispaly_values ${p_vals[@]}
 	echo "${ora}t-values (${gre}${#t_vals[@]}${ora}):${whi}"
 	dispaly_values ${t_vals[@]}
	exit_message 7 -nt
fi # Must have at least 1 t and p-value for cluster corrections

trap control_c SIGINT 2>/dev/null # Finishes background processes before crashing
#---------------------------- FIND STAT FILES ------------------------------#
# Create 'grep -E' input of cope.feat directories
cope_filter=$(printf "%s\$${IFS}" ${c_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed -e 's/|$//' -e 's/\^\$/^/g')
miss_count='0' # Track number of missing stats folders

for i in ${!feat_dirs[@]}; do
	feat_dir="${feat_dirs[${i}]}"
	cope_find=($(find "${feat_dir}/" -name "${cope_dir_name}*${cope_dir_ext}" |grep -E "${cope_filter}" |sed 's@//@/@g')) # Find in linked folders too

	if [ "${#cope_find[@]}" -eq '0' ]; then # If lower-level FEAT or missing desired cope.feats
		if [ "${c_vals[0]}" == '^' ]; then # If no '-c' inputs, ignore null results
			rm_cluster_dir=("${feat_dir}/${output_cluster_dir}") # If removing files
			cope_find=("${feat_dir}/${feat_stats_dir}") # add 'stats' folder
		fi
	else # Sort unique values and add 'stats' folder
		rm_cluster_dir=($(printf "%s/${output_cluster_dir}${IFS}" ${cope_find[@]} |sort -u)) # If removing files
		cope_find=($(printf "%s/${feat_stats_dir}${IFS}" ${cope_find[@]} |sort -u))
	fi

	for j in ${!cope_find[@]}; do
		in_stat="${cope_find[${j}]}"
		if [ -d "${in_stat}" ] || [ -L "${in_stat}" ]; then
			stat_dirs+=("${in_stat}")
		else
			miss_count=$((${miss_count} + 1)) # Track number of missing stats folders 
			echo "${red}MISSING STATS FOLDER: [${whi}${miss_count}${red}] ${ora}${in_stat}${whi}"
		fi
	done # for j in ${!cope_find[@]}

	for j in ${!rm_cluster_dir[@]}; do
		in_cluster="${rm_cluster_dir[${j}]}"
		if [ -d "${in_cluster}" ] || [ -L "${in_cluster}" ]; then # Cluster directories to remove files from
			rm_cluster_dirs+=("${in_cluster}")
		fi
	done # for j in ${!rm_cluster_dir[@]}	
done # for i in ${!feat_dirs[@]}

if [ "${#stat_inputs[@]}" -gt '0' ]; then
	stat_files+=($(printf "%s${IFS}" "${stat_inputs[@]}" |sort -u))
	
	for i in ${!stat_files[@]}; do
		check_cluster_dir=$(dirname "${stat_inputs[${i}]}" |sed 's,/${feat_stats_dir}$,,g')"/${output_cluster_dir}"
		if [ -d "${check_cluster_dir}" ] || [ -L "${check_cluster_dir}" ]; then
			rm_cluster_dirs+=("${check_cluster_dir}")
		fi
	done # for i in ${!stat_inputs[@]}
fi # Add input stat file(s)

if [ "${remove_clusters}" == 'yes' 2>/dev/null ]; then # Remove files
	if ! [ -z "${final_output}" ]; then
		manual_cluster_dir="${final_output}/${output_cluster_dir}"
		if [ -d "${manual_cluster_dir}" ] || [ -L "${manual_cluster_dir}" ]; then
			rm_cluster_dirs+=("${manual_cluster_dir}")
		fi
	fi

	if [ "${#rm_cluster_dirs[@]}" -eq '0' ]; then # Crash if no inputs
		echo "${red}NO '${ora}${output_cluster_dir}${red}' DIRECTORIES FOUND TO REMOVE${whi}"
		exit_message 8 -nt
	else # Sort unique values
		rm_cluster_dirs=($(printf "%s${IFS}" ${rm_cluster_dirs[@]} |sort -u))
	fi
	
	echo "${ora}SEARCHING FOR FILES TO REMOVE...${whi}"
	
	# Generate remove filters
	m_filt='^' # grep '^' gets all values
	p_filt='^' # grep '^' gets all values
	s_filt='^' # grep '^' gets all values
	t_filt='^' # grep '^' gets all values

	if ! [ "${remove_all_stats}" == 'yes' 2>/dev/null ]; then
		if [ "${#m_vals[@]}" -gt '0' ]; then # Remove specified masks only
			m_filt=() # Reset array
			for i in ${!m_vals[@]}; do
				m_val="${m_vals[${i}]}"
				for j in ${!mask_exts[@]}; do
					mask_ext=$(echo "${mask_exts[${j}]}" |sed 's@\.@\\.@g')
					m_filt+=("_"$(basename "${m_val%${mask_ext}}_")) # mask name only
				done
			done # for i in ${!m_vals[@]}
			
			m_filt=$(printf "%s${IFS}" ${m_filt[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//g')
		fi # if [ "${#m_vals[@]}" -gt '0' ]

		if ! [ "${remove_all_p}" == 'yes' 2>/dev/null ]; then
			p_filt=$(printf "_p%s_${IFS}" ${p_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//g')
		fi
		
		if [ "${#s_vals[@]}" -gt '0' ]; then # Remove all stat files
			s_filt=() # Reset array
			for i in ${!nifti_stats[@]}; do
				nifti_stat="${nifti_stats[${i}]}"
				s_filt+=($(printf "/${nifti_stat}%s_${IFS}" ${s_vals[@]}))
			done
			
			s_filt=$(printf "%s${IFS}" ${s_filt[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//g')
		fi
		
		if ! [ "${remove_all_t}" == 'yes' 2>/dev/null ]; then
			t_filt=$(printf "_t%s_${IFS}" ${t_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//g')
		fi
	fi #  if ! [ "${remove_all_stats}" == 'yes' 2>/dev/null ]
	
	for i in ${!rm_cluster_dirs[@]}; do
		rm_cluster_dir="${rm_cluster_dirs[${i}]}"
		all_cluster=($(find "${rm_cluster_dir}/" -type f |sed 's@//@/@g')) # Find in linked folders too
		
		if [ "${#all_cluster[@]}" -eq '0' ]; then
			continue # No files to remove
		else # Filter files
			check_rm_vals=($(printf "%s${IFS}" ${all_cluster[@]} |grep -E "${m_filt}" |grep -E "${p_filt}" |grep -E "${s_filt}" |grep -E "${t_filt}"))
		fi

		if [ "${remove_exception}" == 'yes' 2>/dev/null ]; then
			if [ "${#check_rm_vals[@]}" -eq '0' ]; then # Remove all files
				all_rm_vals+=($(printf "%s${IFS}" ${all_cluster[@]}))
			elif [ "${#check_rm_vals[@]}" -eq "${#all_cluster[@]}" ]; then # Keep all files
				preserved_files+=($(printf "%s${IFS}" ${all_cluster[@]}))
			else # Reverse selection with 'grep -v' (basename of files). Use 'for loop' if error
				all_rm_vals+=($(printf "%s${IFS}" ${all_cluster[@]} |grep -E -v $(printf "%s\$${IFS}" ${check_rm_vals[@]} |sed "s@${rm_cluster_dir}@@g" |tr "${IFS}" '|' |sed 's/|$//g'))) || slow_grep_v ${all_cluster[@]}
				preserved_files+=(${check_rm_vals[@]})
			fi
		else
			all_rm_vals+=($(printf "%s${IFS}" ${check_rm_vals[@]}))
		fi # if [ "${remove_exception}" == 'yes' 2>/dev/null ]
	done # for i in ${!rm_cluster_dirs[@]}
	
	all_rm_vals=($(printf "%s${IFS}" ${all_rm_vals[@]} |sort -u))

	proceed='no'
	until [ "${proceed}" == 'yes' 2>/dev/null ]; do
	
		echo "${ora}FOUND ${gre}${#all_rm_vals[@]} ${ora}FILE(S) TO REMOVE${whi}"
		
		if [ "${remove_exception}" == 'yes' 2>/dev/null ]; then
			echo "${ora}EXCEPTION USED: RETAINING ${gre}${#preserved_files[@]} ${ora}SPECIFIED FILE(S)${whi}"
		fi

		echo "${pur}MASK(S): ${whi}"
		display_values $(echo "${m_filt}" |tr '|' "${IFS}" |sed -e 's@^_@@g' -e 's/_$//g' -e 's/^\^$/ALL MASKS/g')
		
		echo "${pur}P-VALUE(S): ${whi}"
		display_values $(echo "${p_filt}" |tr '|' "${IFS}" |sed -e 's@\\@@g' -e 's@^_p@@g' -e 's/_$//g' -e 's/^\^$/ALL P-VALUES/g')
		
		echo "${pur}STAT FILE TYPE(S): ${whi}"
		display_values $(echo "${s_filt}" |tr '|' "${IFS}" |sed -e 's@\\@@g' -e 's@^/@@g' -e 's/_$//g' -e 's/^\^$/ALL STAT FILE TYPES/g')
		
		echo "${pur}T OR Z-VALUE(S): ${whi}"
		display_values $(echo "${t_filt}" |tr '|' "${IFS}" |sed -e 's@\\@@g' -e 's@^_t@@g' -e 's/_$//g' -e 's/^\^$/ALL T OR Z-VALUES/g')

		if [ "${#all_rm_vals[@]}" -eq '0' ]; then
			exit_message 0 -nt
		fi # If no files to remove
		
		echo "${ora}[${gre}ls${ora}] LIST ${gre}${#all_rm_vals[@]} ${ora}FILES TO REMOVE${whi}"
		echo "${ora}[${gre}rm${ora}] REMOVE ${gre}${#all_rm_vals[@]} ${ora}FILES${whi}"
		
		if [ "${remove_exception}" == 'yes' 2>/dev/null ] && [ "${#preserved_files[@]}" -gt '0' ]; then
			echo "${ora}[${gre}v${ora}]  VIEW ${gre}${#preserved_files[@]} ${ora}FILES TO KEEP${whi}"
		fi
		
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
			
			for i in ${!rm_cluster_dirs[@]}; do
				in_rm_dir="${rm_cluster_dirs[${i}]}"
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
			invalid_msg "${user_remove}"
		fi # if [ "${user_remove}" == 'l' 2>/dev/null ] || [ "${user_remove}" == 'ls' 2>/dev/null ]
	done # until [ "${proceed}" == 'yes' 2>/dev/null ]
else # Check stats directories
	if [ "${include_brain}" == 'no' 2>/dev/null ] && [ "${#m_vals[@]}" -eq '0' ]; then
		echo "${red}MUST SPECIFY MASK INPUT(S) ${pur}-m${red} IF EXCLUDING WHOLE BRAIN ${pur}-nb${whi}"
		exit_message 9 -nt
	fi
	
	if [ "${#stat_dirs[@]}" -eq '0' ] && [ "${#stat_files[@]}" -eq '0' ]; then
		echo "${red}NO '${ora}stats${red}' DIRECTORIES FOUND${whi}"
		exit_message 10 -nt
	elif [ "${#stat_dirs[@]}" -gt '0' ]; then
		echo "${ora}SEARCHING FOR STAT FILES...${whi}"
	
		# Create 'grep -E' input and find stat files
		for i in ${!nifti_stats[@]}; do # Loop through stat types
			nifti_stat="${nifti_stats[${i}]}"
			if [ "${#s_vals[@]}" -eq '0' ]; then
				stat_filter='^' # Get all stat files
			else # Get input values
				stat_filter=$(printf "${nifti_stat}%s${feat_stats_ext}\$${IFS}" ${s_vals[@]} |sort -u |sed 's@\.@\\.@g' |tr "${IFS}" '|' |sed 's/|$//g')
			fi # if [ "${#s_vals[@]}" -eq '0' ]

			for j in ${!stat_dirs[@]}; do
				stat_dir="${stat_dirs[${j}]}"
				stat_files+=($(find "${stat_dir}/" -maxdepth 1 -name "${nifti_stat}[0-9]*${feat_stats_ext}" |grep -E "${stat_filter}" |sed 's@//@/@g')) # Find in linked folders too
			done
		done # for i in ${!nifti_stats[@]}
	fi # if [ "${#stat_dirs[@]}" -eq '0' ] && [ "${#stat_files[@]}" -eq '0' ]
	
	stat_files=($(printf "%s${IFS}" ${stat_files[@]} | sort -u)) # Sort unique stat files
	if [ "${#stat_files[@]}" -eq '0' ]; then
		echo "${red}NO STAT FILES${whi}"
		exit_message 0 -nt
	fi
	
	if [ "${#feat_dirs[@]}" -eq '0' ] || [ "${include_brain}" == 'no' 2>/dev/null ]; then # Do not include whole brain output
		total_corrections=$(echo |awk "{print ${#stat_files[@]}*${#m_vals[@]}*${#p_vals[@]}*${#t_vals[@]}}")
	else
		total_corrections=$(echo |awk "{print ${#stat_files[@]}*(${#m_vals[@]} + 1)*${#p_vals[@]}*${#t_vals[@]}}")
	fi
	
	proceed='no' # Wait for user input to continue
	until [ "${proceed}" == 'yes' ]; do
		echo "${gre}FOUND ${ora}${#stat_files[@]} ${gre}STAT FILE(S)${whi}"
		
		if ! [ -z "${final_output}" ]; then
			echo "${pur}OUTPUT FOLDER FOR ${red}ALL ${pur}FILES: ${ora}${final_output}${whi}"
		fi
		
		echo "${pur}MASK(S): ${whi}"
		if [ "${#feat_dirs[@]}" -eq '0' ] || [ "${include_brain}" == 'no' 2>/dev/null ]; then  # Do not include whole brain output
			display_values ${m_vals[@]}
		else # Search for whole brain in FEAT folder(s)
			display_values "${whole_brain_output}" ${m_vals[@]}
		fi
		
		echo "${pur}P-VALUE(S): ${whi}"
		display_values ${p_vals[@]}
		
		echo "${pur}T OR Z-VALUE(S): ${whi}"
		display_values ${t_vals[@]}

		if [ "${force_create}" == 'yes' 2>/dev/null ]; then
			echo "${ora}CORRECTING ${gre}${total_corrections} ${ora}TIME(S) USING ${gre}${#stat_files[@]}${ora} STAT FILES${whi}"
			echo "${gre}CORRECTING IN ${pur}${wait_time} ${gre}SECONDS: ${whi}"
			
			for i in $(seq 1 1 "${wait_time}"); do
				printf "${i} "
				sleep 1
			done # Allow user to crash script if needed
			
			printf '\n'
			proceed='yes'
		else # Prompt user
			echo "${ora}[${gre}c${ora}]  CLUSTER CORRECT ${gre}${total_corrections} ${ora}TIME(S) USING ${gre}${#stat_files[@]}${ora} STAT FILES?${whi}"
			echo "${ora}[${gre}ls${ora}] LIST ${gre}${#stat_files[@]}${ora} STAT FILES?${whi}"
			echo "${ora}[${gre}x${ora}]  EXIT SCRIPT${whi}"
			printf "${ora}ENTER OPTION:${whi}"
		
			read -r stat_status
			if [ "${stat_status}" == 'c' 2>/dev/null ]; then
				proceed='yes'
			elif [ "${stat_status}" == 'l' 2>/dev/null ] || [ "${stat_status}" == 'ls' 2>/dev/null ]; then
				display_values ${stat_files[@]}
			elif [ "${stat_status}" == 'q' 2>/dev/null ] || [ "${stat_status}" == 'x' 2>/dev/null ]; then
				exit_message 0 -nt
			else
				invalid_msg "${stat_status}"
			fi
		fi
	done # until [ "${proceed}" == 'yes' ]
	
	file_increment='0'
	for i in ${!stat_files[@]}; do # Cluster correct all stat files
		stat_file="${stat_files[${i}]}"
		dir_stat=$(dirname "${stat_file}")'/' # Add '/' to remove full folder in "${cope_dir}"
		file_count="${file_increment}" # Increment file count each iteration
		
		if [ "${include_brain}" == 'yes' 2>/dev/null ]; then
			file_increment=$(echo |awk "{print ${file_increment} + (${#t_vals[@]} * ${#p_vals[@]} * (1 + ${#m_vals[@]}))}")
		else # Do not include brain mask
			file_increment=$(echo |awk "{print ${file_increment} + (${#t_vals[@]} * ${#p_vals[@]} * ${#m_vals[@]})}")
		fi
		
		cope_dir="${dir_stat%/${feat_stats_dir}/*}"
		
		if [ -z "${final_output}" ]; then
			out_dir="${cope_dir}"
		else
			out_dir="${final_output}"
		fi
		
		check_complete_dir=($(printf "%s${IFS}" ${completed_dirs[@]} |grep "^${out_dir}$")) # Do not repeat mask edits
		completed_dirs+=("${cope_dir}")

		# Create mask edits
		if [ "${#check_complete_dir[@]}" -eq '0' ]; then
			wait # Wait for background processes to finish
			brain_mask="${cope_dir}/${whole_brain_mask}"
			edit_mask_dir="${out_dir}/${output_cluster_dir}/${output_mask_edits}"
			
			if [ "${include_brain}" == 'no' 2>/dev/null ]; then
				brain_master=''
			elif ! [ -f "${brain_mask}" ] && [ "${#stat_inputs[@]}" -eq '0' ]; then # Edit with brain mask to avoid empty voxels
				echo "${red}MISSING WHOLE BRAIN MASK: ${ora}${brain_mask}${whi}"
				continue
			fi
			
			if ! [ -d "${edit_mask_dir}" ]; then
				mkdir -p "${edit_mask_dir}" || vital_error_loop "${edit_mask_dir}" "${LINENO}"
			fi
			
			if ! [ -f "${brain_mask}" ] && [ "${#stat_inputs[@]}" -gt '0' ]; then
				brain_master='' # No master brain file (use mask inputs only)
			elif [ "${include_brain}" == 'yes' 2>/dev/null ]; then
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
		if ! [ -z "${brain_master}" ]; then
			all_masks=($(printf "%s${IFS}" "${brain_master}" ${m_vals[@]})) # include whole brain mask by default
		else # Do not inclue whole brain mask
			all_masks=($(printf "%s${IFS}" ${m_vals[@]})) # raw mask values only
		fi
		
		# Cluster correct stat files
		for j in ${!all_masks[@]}; do
			in_mask="${all_masks[${j}]}"
			
			if ! [ -z "${brain_master}" ] && [ "${in_mask}" == "${brain_master}" 2>/dev/null ]; then
				edit_mask="${brain_master}" # Whole brain has different naming convention
			else
				edit_mask="${edit_mask_dir}/"$(basename "${in_mask%.nii*}")"${output_edit_name}.nii.gz"
			fi
			
			if [ -f "${edit_mask}" ]; then
				base_mask=$(basename "${edit_mask%.nii*}" |sed "s/${output_edit_name}$//g")
				mask_cluster_dir="${out_dir}/${output_cluster_dir}/${base_mask}"
				
				if ! [ -d "${mask_cluster_dir}" ]; then
					mkdir -p "${mask_cluster_dir}" || vital_error_loop "${mask_cluster_dir}" "${LINENO}"
				fi
				
				for k in ${!p_vals[@]}; do
					p_val="${p_vals[${k}]}"
					
					for m in ${!t_vals[@]}; do
						t_val="${t_vals[${m}]}"
						file_count=$((${file_count} + 1))
						
						out_stat="${mask_cluster_dir}/"$(basename "${stat_file%.nii*}")"_${base_mask}_t${t_val}_p${p_val}_grf"
						echo "${ora}[${gre}${file_count}${ora}/${gre}${total_corrections}${ora}] ${pur}CREATING: ${ora}${out_stat}${whi}"
						cluster_func "${stat_file}" "${edit_mask}" "${out_stat}" & # Process in background to speed processing
						control_bg_jobs
					done # for m in ${!t_vals[@]}
				done # for k in ${!p_vals[@]}
			fi # if [ -f "${edit_mask}" ]
		done # for j in ${!all_masks[@]}
	done # for i in ${!stat_files[@]}
fi # if [ "${remove_clusters}" == 'yes' 2>/dev/null ]

exit_message 0