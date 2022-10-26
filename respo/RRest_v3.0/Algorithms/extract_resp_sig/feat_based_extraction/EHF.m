function EHF(option, up)
% EHF eliminates very high frequencies from signals.
%	            EHF(option, up)
%
%	Inputs:
%		option          the option which has led to this function being used
%       up              universal parameters structure
%

fprintf('\n--- Eliminating VHFs ');
log_int_respSig = 1;             % Has value 1 unless this is a final respiratory signal

for subj = up.paramSet.subj_list
    
    sig_type = option(1:3);
    %% Cycle through each signal of this type
    eval(['sigs = up.paramSet.' sig_type '_sigs;']);
    for sig_no = 1 : length(sigs)
        curr_sig = sigs{sig_no};
        
        %% Skip if this processing has been done previously
        eval(['save_name = ''' curr_sig, up.paths.filenames.elim_vhf ''';']);
        iden_resp_sig_file_ending
        savepath = [up.paths.data_save_folder, num2str(subj), ending];
        exist_log = check_exists(savepath, save_name);
        if exist_log
            continue
        end
        
        %% Load relevant data
        if ~exist('data', 'var')
            load([up.paths.data_load_folder, up.paths.data_load_filename]);
        end
        
        %% Select appropriate filter characteristics
        eval(['rel_data = data(subj).' curr_sig ';']);
        if strcmp(sig_type, 'ppg')
            filt_characteristics = up.paramSet.elim_vhf.ppg;
        elseif strcmp(sig_type, 'ekg')
            filt_characteristics = up.paramSet.elim_vhf.ekg;
        end
        
        %% eliminate very high frequencies
        s = rel_data.v;
        s_filt.fs = rel_data.fs;
        s_filt.v = elim_vhfs(s, s_filt.fs, filt_characteristics);
        s_filt.t = (1/s_filt.fs)*(1:length(s_filt.v));
        
        %% eliminate mains frequencies
        % only applicable to the ECG
        if strcmp(sig_type, 'ekg')
            filt_characteristics = up.paramSet.elim_mains;
            s_filt.fs = rel_data.fs;
            s_filt.v = elim_mains(s_filt.v, s_filt.fs, filt_characteristics);
            s_filt.t = (1/s_filt.fs)*(1:length(s_filt.v));
        end
        
        %% Save processed data
        eval([save_name ' = s_filt;']);
        save_or_append_data
        
    end
    
end

end