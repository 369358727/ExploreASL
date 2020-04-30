function xASL_bids_FromDataPar2JSON(DataParPath)
%xASL_bids_FromDataPar2JSON Take DataPar ASL parameters and move them to JSON sidecars per BIDS
%
% FORMAT: [x] = xASL_bids_FromDataPar2JSON(DataParPath)
% 
% INPUT:
%   DataParPath - path to data parameter JSON file (REQUIRED)
%                         
% -----------------------------------------------------------------------------------------------------------------------------------------------------
% DESCRIPTION: This function takes all parameters from the DataPar & moves them into all lower-level JSONs, per BIDS inheritance
% Note that this function assumes that the DataPar file is in the ROOT folder of the study, that contains all the JSON sidecars.
% Also note that this function will recursively create JSON files (if non-existing) for all NIfTI files, so is supposed to run on raw data only.
%
% This function runs the following steps:
% 1) Load parent DataPar JSON file
% 2) Get list of NIfTIs (i.e. "children" that will get the parameters)
% 3) Load & add JSON child (if exist) to memory
% 4) Load & add parms.mat child (if exist (legacy)) to memory
% 5) Add parent fields to memory
% 6) Save (& overwrite if existed) new JSON from memory
% 7) Delete parms.mat if existed
% 
% -----------------------------------------------------------------------------------------------------------------------------------------------------
% EXAMPLE: xASL_bids_FromDataPar2JSON('/MyStudy/DataParameterFile.json');
% __________________________________
% Copyright 2015-2020 ExploreASL

%% 1) Load DataPar file
if nargin<1 || isempty(DataParPath) || ~exist(DataParPath, 'file')
    error('Invalid input argument or non-existing DataPar file');
end

DataPar = xASL_import_json(DataParPath);

%% 2) Get list of NIfTIs
AnalysisDir = fileparts(DataParPath);

fprintf('Obtaining list of NIfTIs\n');
FileList = xASL_adm_GetFileList(AnalysisDir, '^.*\.nii$','FPListRec',[0 Inf]);

for iList=1:length(FileList)
    xASL_TrackProgress(iList, length(FileList));
    [Fpath, Ffile] = xASL_fileparts(FileList{iList});
    PathJSON = fullfile(Fpath, [Ffile '.json']);
    PathMAT = fullfile(Fpath, [Ffile '_parms.mat']);
    
    %% 3) Load & add JSON child if exist
    if exist(PathJSON, 'file')
        JSON = xASL_import_json(PathJSON);
    else
        JSON = struct;
    end
    
    %% 4) Load & add parms.mat child if exist (legacy)
    if exist(PathMAT, 'file')
        mat = load(PathMAT,'-mat');
        JSON = InsertFields(mat.parms, JSON);
    end
    
    %% 5) Add parent fields
    JSON = InsertFields(DataPar, JSON);
    
    %% 6) Save (& overwrite if existed) new JSON
    spm_jsonwrite(PathJSON, JSON);
    %% 7) Delete parms.mat if existed
    xASL_delete(PathMAT);
end

fprintf('\n');

end


function [JSON] = InsertFields(DataPar, JSON)
%InsertFields

    FieldsAre = fields(DataPar);

    Fields2Skip = {'Quality' 'DELETETEMP' 'subject_regexp' 'name' 'exclusion' 'exclusionReason' 'SESSIONS' 'ROOT'};
    % These fields are environment parameters, not ASL-specific parameters

    for iField=1:length(FieldsAre)
        SkipField = max(cellfun(@(y) strcmp(FieldsAre{iField},y), Fields2Skip));
        if ~SkipField
            FieldValue = DataPar.(FieldsAre{iField});
            if ischar(FieldValue) || isnumeric(FieldValue) || islogical(FieldValue)


                if isfield(JSON,FieldsAre{iField})
                    % Skip this field: per inheritance principle, daughters
                    % fields have preference
                    % Also skip this field if it is an environment parameter
                else
                    JSON.(FieldsAre{iField}) = DataPar.(FieldsAre{iField});
                end
            else % assume we have subfields
                try
                    Subfields = fields(DataPar.(FieldsAre{iField}));
                catch ME
                    warning(['Something went wrong with field ' FieldsAre{iField}]);
                    fprintf('Is this field not char/numeric and it doesnt have subfields?\n');
                    fprintf('%s\n', ME.message);
                    continue; % with next field
                end
                % do the same for the subfields
                if ~isfield(JSON,FieldsAre{iField})
                    JSON.(FieldsAre{iField}) = struct;
                end

                JSON.(FieldsAre{iField}) = InsertFields(DataPar.(FieldsAre{iField}), JSON.(FieldsAre{iField}));
            end
        end
    end

end

