function ZZ = fmri_prep_temporal(DATApath, fMRIpath, subj, REGRESSORS)
% Z: detrended, bandpass filtered, regressed the effects from WM, CSF,
% global signal
% Y: detrended brain signal
global FMRI


%  PARAMETERS FOR TEMPORAL FMRI DATA PROCESSING
%__________________________________________________________________________

TR        = FMRI.prep.TR;        % TR time: volume acquisition time
BW        = FMRI.prep.BW;        % frequency range for bandpass filter
dummyoff  = FMRI.prep.dummyoff;  % num. of dummy data from beginning
prefix    = FMRI.prep.prefix;

doCompCor = FMRI.prep.PCA;
nCompCor  = FMRI.prep.nPCA;



%  LOAD BRAIN ATLAS: AAL or FSURF
%__________________________________________________________________________

subjpath = fullfile(DATApath,subj,fMRIpath);
fn_nii = sprintf('^%srest.nii$',prefix);
fns = spm_select('FPList',subjpath,fn_nii);
if isempty(fns)
    fn_img = sprintf('^%srest.nii.gz$',prefix);
    fns = spm_select('FPList',subjpath,fn_img);
end

% Get Reference Image for the Brain Mask Extraction
vref = spm_vol(fns(1,:));
if length(vref)>1, vref=vref(1); end;
[idbrainmask, idgm, idwm, idcsf] = fmri_load_maskindex(vref);

fprintf('    : Nuisance Regression and Bandpass Filtering\n');


% Get Motion Parameters and Scanning Info
rpname = fullfile(subjpath,'rp_*.txt');
rpname = dir(rpname);

if isempty(rpname),
    errordlg('WARNING: motion parameter for %s does not exist...\n',subj);
else
    rpname=fullfile(subjpath, rpname(1).name);
end;



% LOAD fMRI Volumes
vs = spm_vol(fns); DIM = vs(1).dim;


% total number of fmri scans
nscanfmri = length(vs);
scans     = dummyoff+1:nscanfmri;
nscan     = length(scans);


% load Motion Parameters and
% detrending motion parameters
vs = vs(scans);
MOTION = dlmread(deblank(rpname)); % motion covariates
MOTION = MOTION(scans,:);
MOTION = detrend(MOTION,'linear');
fprintf('    : 6-parameters (x,y,z,pitch,roll,yaw) were modeled.\n');


% derivative 12-parameter model
if 0,
    derMotion = zeros(size(MOTION));
    derMotion(2:end,:) = diff(MOTION);    MOTION = [MOTION, derMotion];
    fprintf('    : 12-parameters (motion and its derivative) were modeled.\n');
end


% load Volume Images
Y  = spm_read_vols(vs);
Y  = reshape(Y,prod(vref.dim(1:3)),nscan);


% 1. Linear Detrending of BOLD signal
Y = detrend(Y','linear')';


% 2. Extract WM, CSF, and Global signal
WM  = mean(Y(idwm,:),1)';
CSF = mean(Y(idcsf,:),1)';
GS  = mean(Y(idbrainmask,:),1)';



%  Select Types of regressors
%__________________________________________________________________

st = dummyoff+1;
NUIS = [];
if REGRESSORS(4),  NUIS = [NUIS, MOTION];       end

if doCompCor==1,
    % Extract Physiological Noise using CompCor method
    noisePhy = [];
    if REGRESSORS(2), noisePhy = [noisePhy; Y(idwm,:)]; end
    if REGRESSORS(3), noisePhy = [noisePhy; Y(idcsf,:)]; end
    
    % Singular Value Decomposition
    [U, S, V] = svd(noisePhy','econ');
    noiseComp = U(:,1:nCompCor);
    NUIS = [NUIS, noiseComp];
    fprintf('    : %d-PCs of physiological noises were modeled.\n',nCompCor);
else
    % Extract Physiological Noise using mean value
    if REGRESSORS(1), NUIS = [NUIS, GS];         end
    if REGRESSORS(2), NUIS = [NUIS, WM];         end
    if REGRESSORS(3), NUIS = [NUIS, CSF];        end
end



% Normalization of NUIS is not necessary process..
% mNUIS=repmat(mean(NUIS),nscan,1);
% stdNUIS=repmat(std(NUIS),nscan,1);
% NUIS=(NUIS-mNUIS)./ stdNUIS;


% 3. Regressing out the Nuisance parameters in BOLD signal
Y_reg = iRSFC_NUIS_regress(Y(idbrainmask,:)',NUIS)';
Z1 = zeros(prod(vs(1).dim),length(vs));
Z1(idbrainmask,:) = Y_reg; clear Y;


% Write temporary files
spm_write_vols(vref, Z1, subjpath, 'cleaned');



% 4. Bandpass filtering of BOLD signal
Y_bpf = rest_IdealFilter(Z1(idbrainmask,:)',TR,BW)';
ZZ = zeros(prod(vs(1).dim),length(vs));
ZZ(idbrainmask,:) = Y_bpf; clear Y_bpf;


% Write temporary files
spm_write_vols(vref, ZZ, subjpath, 'cleaned_bpf');
