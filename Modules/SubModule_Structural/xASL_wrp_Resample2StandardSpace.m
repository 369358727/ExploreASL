function xASL_wrp_Resample2StandardSpace(x)
%xASL_wrp_Resample2StandardSpace Submodule of ExploreASL Structural Module, that resamples all structural images & derivatives
% to standard space
%
% FORMAT: xASL_wrp_Resample2StandardSpace(x)
%
% INPUT:
%   x 	    - structure containing fields with all information required to run this submodule (REQUIRED)
%   x.P     - paths with NIfTIs for which this function should be applied to (REQUIRED)
%
% OUTPUT: n/a
%
% -----------------------------------------------------------------------------------------------------------------------------------------------------
% DESCRIPTION: This submodule resamples all structural images & their derivatives to standard space. It uses the transformation
% fields that were obtained previously in the Structural module, concatenates all transformations into a single transformation
% (if not already done) & applies the transformation with a single interpolation (either trilinear for low quality or probability
% maps, or 2nd order B-spline). Finally, it computes the Jacobian determinants (i.e. the derivative of the transformation field)
% to obtain a map of the volumetric effects of the transformation. This Jacobian map is multiplied with the standard space resampled
% images, to restore their (local & global) total volume. The sum of volumes in native & standard space are compared as QC.
% This submodule is not only part of the structural module, but can be repeated when the transformation map is edited, e.g. after
% longitudinal registration or after creation of a group-wise template.
%
%
% EXAMPLE: xASL_wrp_Resample2StandardSpace(x);
% __________________________________
% Copyright (C) 2015-2019 ExploreASL
%
% 2019-05-02 HJM





%% -----------------------------------------------------------------
%% 1) Define pathname list of structural images to be resliced
fprintf('%s\n','Reslice structural images & move to Population folder');

INname         = {x.P.Path_T1; x.P.Path_c1T1; x.P.Path_c2T1};
OUTname        = {x.P.Pop_Path_rT1; x.P.Pop_Path_rc1T1; x.P.Pop_Path_rc2T1};

if xASL_exist(x.P.Path_c3T1, 'file')
    INname{end+1} = x.P.Path_c3T1;
    OUTname{end+1} = x.P.Pop_Path_rc3T1;
end            

if xASL_exist(x.P.Path_FLAIR, 'file')
    INname{end+1} = x.P.Path_FLAIR;
    OUTname{end+1} = x.P.Pop_Path_rFLAIR;
end

%% -----------------------------------------------------------------
%% 2) Perform the resampling
xASL_spm_deformations(x, INname, OUTname);

% Lesion probability maps (do linear interpolation to avoid negative edge effects)
xASL_spm_deformations(x, x.P.Path_WMH_SEGM, x.P.Pop_Path_rWMH_SEGM, 1);

[INname, OUTname] = xASL_adm_LesionResliceList(x);

if ~isempty(INname) && ~isempty(OUTname)
    % First dilate ROIs, if they were e.g. used for annotation (single voxel only)
    % Do linear interpolation to avoid negative edge effects
    for iL=1:length(INname)
        xASL_im_dilateROI(INname{iL});
    end
    xASL_spm_deformations(x,INname, OUTname,1);
end

%% -----------------------------------------------------------------
%% 3) Compute Jacobian determinants & multiply PV maps for modulation
xASL_im_Modulation(x);


end



