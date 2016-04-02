# vds2ppl2vds
Little shell script which syncs contacts between vdirsyncer and ppl.


## Delimitations

 * If two versions of a vCard (vcf file) differ they will no be merged. However, the later version of both files will be used.


## Usage

 1. Move the script to the desired positon `cp vds2ppl2vds.sh DESIREDPOSITION`
 2. Set the variables `VDS`, `PPL`, `VDS_CONTACTS`, `PPL_CONTACTS`, and `FILE_LAST_SYNC_TIME` inside of the script according to your system setup.
 3. Do a backup of your files (this script is hardly tested).
 4. Run the script with `./vds2ppl2vds.sh`
