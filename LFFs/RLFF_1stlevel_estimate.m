function RLFF_1stlevel_estimate(subjname,fmridir)
global FMRI

fprintf('\n-----------------------------------------------------------------------\n');
fprintf('  1st LEVEL MOODEL ESTIMATION ... \n');
fprintf('-----------------------------------------------------------------------\n');


%  SPECIFY your own study
%--------------------------------------------------------------------------
OUTpath    = fullfile(FMRI.anal.FC.OUTpath,'LFFs_1stlevel');



%  START THE SPM BATCH JOBS
%--------------------------------------------------------------------------
spm('Defaults', 'fMRI')
spm_jobman('initcfg');  %% Useful in SPM8 only
clear jobs;

outdir = fullfile(OUTpath,subjname,fmridir);
SPMmat = fullfile(outdir,'SPM.mat');

jobs{1}.stats{1}.fmri_est.spmmat = cellstr(SPMmat);
jobs{1}.stats{1}.fmri_est.method.Classical = 1;

% spm_jobman('interactive',jobs);  % open a GUI containing all the setup
spm_jobman('run',jobs);


