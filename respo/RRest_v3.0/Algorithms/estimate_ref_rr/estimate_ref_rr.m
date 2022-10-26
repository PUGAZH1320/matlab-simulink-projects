function estimate_ref_rr(up)
%ESTIMATE_REF_RR estimates a reference RR from reference respiratory
%signals.
%	            estimate_ref_rr(up)
%
%	Inputs:
%		data            data files should be stored in the specified
%                       format. At least one reference respiratory signal
%                       is required (either thoracic impedance, known as
%                       "imp" in this file, or  oral-nasal air pressure,
%                       known as "paw" in this file).
%       up              universal parameters structure
%
%	Outputs:
%       "n_rrEsts.mat"  A series of files for each of n subjects, in which
%                       is stored the reference RR for each window.
%

fprintf('\n--- Estimating Reference RRs ');

% For each subject
for subj = up.paramSet.subj_list
    
    % Skip if this processing has been done previously
    save_name = 'rr_ref';
    savepath = [up.paths.data_save_folder, num2str(subj), up.paths.filenames.ref_rrs, '.mat'];
    exist_log = check_exists(savepath, save_name);
    if exist_log
        %continue
    end
    
    %% Load window timings
    % These were generated during estimation of RRs from the ECG and PPG.
    loadpath = [up.paths.data_save_folder, num2str(subj), up.paths.filenames.win_timings, '.mat'];
    load(loadpath);
    
    %% Load data
    % if the raw data matrix hasn't already been loaded, load it
    if ~exist('data', 'var')
        load([up.paths.data_load_folder, up.paths.data_load_filename]);
    end
    
    %% Find additional RRs from simultaneous impedance numerics
    if up.analysis.imp_stats
        rr_ref.imp = find_rr_ref_from_ref_rrs(wins, data, subj);
    end
    
    %% Find ref RRs from breath timings
    if strcmp(up.paramSet.ref_method, 'breaths')
        rr_ref = find_rr_ref_from_ref_breaths(wins, data, subj, up);
        save_or_append_data
        continue
    end
    
    %% Find ref RRs from original simultaneous RRs
    if strcmp(up.paramSet.ref_method, 'rrs')
        rr_ref = find_rr_ref_from_ref_rrs(wins, data, subj);
        save_or_append_data
        continue
    end
    
    %% Find ref RRs from simultaneous pressure respiratory signal
    if strcmp(up.paramSet.ref_method, 'paw')
        % Extract respiratory signals
        ext_sig = extract_resp_sigs(data, subj, up);
        % Determine SNRs
        snr_sig = calc_snrs(ext_sig, subj, wins, up);
        clear ext_sig
        % LPF to exclude freqs above resp
        lpf_sig = lpf_to_exclude_resp(snr_sig, subj, up);
        clear snr_sig
        % setup
        no_wins = length(wins.t_start);
        temp_t = mean([wins.t_start(:)' ; wins.t_end(:)']); temp_t = temp_t(:);
        rr_ref.v = nan(length(wins.t_start),1);
        rr_ref.snr_log = false(length(wins.t_start),1);
        % cycle through each window
        breath_times = [];
        for win_no = 1 : no_wins
                % select data for this window
                rel_els = find(lpf_sig.t >= wins.t_start(win_no) & lpf_sig.t <= wins.t_end(win_no));
                rel_data.t = lpf_sig.t(rel_els);
                rel_data.v = lpf_sig.v(rel_els);
                % interpolate data to be at fixed time values
                downsample_freq = 5;
                interp_data.t = wins.t_start(win_no): (1/downsample_freq) : wins.t_end(win_no);
                interp_data.v = interp1(rel_data.t, rel_data.v, interp_data.t, 'linear');
                % get rid of nans
                interp_data.v(isnan(interp_data.v)) = median(interp_data.v(~isnan(interp_data.v)));
                % normalise data
                rel_sig.v = (interp_data.v - mean(interp_data.v))/std(interp_data.v);
                rel_sig.t = interp_data.t;
                rel_sig.snr = lpf_sig.snr;
                rel_sig.fs = downsample_freq;
                clear rel_data interp_data
                % Identify positive gradient threshold-crossings
                [rr_ref.v(win_no), rr_ref.snr_log(win_no), temp_breath_times] = pos_grad_thresh(rel_sig, wins, win_no, up);
                rr_ref.t = temp_t;
                % store breath times
                breath_times =[breath_times; temp_breath_times(:)];
                clear rel_sig ave_breath_duration win_breaths el sig downsample_freq rel_els rel_paw rel_imp
        end
        clear no_wins s wins win_no temp_t lpf_sig
        
        %% Save ref RRs to file
        save_or_append_data
        master_breath_times{subj} = breath_times;
        clear rr_ref breath_times
    end
    
    %% Find ref RRs from simultaneous impedance respiratory signal using impedance SQI
    if strcmp(up.paramSet.ref_method, 'imp_sqi')
        % Extract respiratory signals
        ext_sig = extract_resp_sigs(data, subj, up);
        % Determine SNRs
        snr_sig = calc_snrs(ext_sig, subj, wins, up);
        clear ext_sig
        % LPF to exclude freqs above resp
        lpf_sig = lpf_to_exclude_resp(snr_sig, subj, up);
        clear snr_sig
        % setup
        no_wins = length(wins.t_start);
        temp_t = mean([wins.t_start(:)' ; wins.t_end(:)']); temp_t = temp_t(:);
        rr_ref.v = nan(length(wins.t_start),1);
        rr_ref.snr_log = false(length(wins.t_start),1);
        % cycle through each window
        for win_no = 1 : no_wins
            % select data for this window
            rel_els = find(lpf_sig.t >= wins.t_start(win_no) & lpf_sig.t <= wins.t_end(win_no));
            rel_data.t = lpf_sig.t(rel_els);
            rel_data.v = lpf_sig.v(rel_els);
            % interpolate data to be at fixed time values
            downsample_freq = 5;
            interp_data.t = wins.t_start(win_no): (1/downsample_freq) : wins.t_end(win_no);
            interp_data.v = interp1(rel_data.t, rel_data.v, interp_data.t, 'linear');
            % get rid of nans
            interp_data.v(isnan(interp_data.v)) = median(interp_data.v(~isnan(interp_data.v)));
            % normalise data
            rel_sig.v = (interp_data.v - mean(interp_data.v))/std(interp_data.v);
            rel_sig.t = interp_data.t;
            rel_sig.snr = lpf_sig.snr;
            rel_sig.fs = downsample_freq;
            clear rel_data interp_data
            % find troughs and peaks
            [novel_sqi, novel_rr, ~, ~, ~, ~] = ref_cto_mod(rel_sig, up, 'no');
            % Final RR for this window
            rr_ref.v(win_no,1) = novel_rr;
            rr_ref.snr_log(win_no,1) = novel_sqi;
            clear novel_rr novel_sqi 
            
            clear rel_sig rr_cto rr_fft rrs rel_data interp_data downsample_freq rel_els
            
        end
        clear no_wins s wins win_no temp_t lpf_sig
        
        %% Save ref RRs to file
        save_or_append_data
        clear rr_ref
    end
    
    %% Find ref RRs from simultaneous impedance respiratory signal using agreement method
    if strcmp(up.paramSet.ref_method, 'imp_agree')
        % Extract respiratory signals
        ext_sig = extract_resp_sigs(data, subj, up);
        % Determine SNRs
        snr_sig = calc_snrs(ext_sig, subj, wins, up);
        clear ext_sig
        % LPF to exclude freqs above resp
        lpf_sig = lpf_to_exclude_resp(snr_sig, subj, up);
        clear snr_sig
        % setup
        no_wins = length(wins.t_start);
        temp_t = mean([wins.t_start(:)' ; wins.t_end(:)']); temp_t = temp_t(:);
        rr_ref.v = nan(length(wins.t_start),1);
        rr_ref.snr_log = false(length(wins.t_start),1);
        % cycle through each window
        for win_no = 1 : no_wins
            % select data for this window
            rel_els = find(lpf_sig.t >= wins.t_start(win_no) & lpf_sig.t <= wins.t_end(win_no));
            rel_data.t = lpf_sig.t(rel_els);
            rel_data.v = lpf_sig.v(rel_els);
            % interpolate data to be at fixed time values
            downsample_freq = 5;
            interp_data.t = wins.t_start(win_no): (1/downsample_freq) : wins.t_end(win_no);
            interp_data.v = interp1(rel_data.t, rel_data.v, interp_data.t, 'linear');
            % get rid of nans
            interp_data.v(isnan(interp_data.v)) = median(interp_data.v(~isnan(interp_data.v)));
            % normalise data
            rel_sig.v = (interp_data.v - mean(interp_data.v))/std(interp_data.v);
            rel_sig.t = interp_data.t;
            rel_sig.snr = lpf_sig.snr;
            rel_sig.fs = downsample_freq;
            clear rel_data interp_data
            % perform combined CtO and FFT analysis:
            % CtO
            rr_cto = ref_cto(rel_sig, up);
            % FFT
            rr_fft = ref_fft(rel_sig, downsample_freq, up);
            % Final RR for this window
            rrs = [rr_cto, rr_fft];
            if range(rrs) < 2
                rr_ref.v(win_no,1) = mean(rrs);
                rr_ref.snr_log(win_no,1) = true;
            else
                rr_ref.v(win_no,1) = nan;
                rr_ref.snr_log(win_no,1) = false;
            end
            
            clear rel_sig rr_cto rr_fft rrs rel_data interp_data downsample_freq rel_els
            
        end
        clear no_wins s wins win_no temp_t lpf_sig
        
        %% Save ref RRs to file
        save_or_append_data
        clear rr_ref
    end
    
    %% Find ref RRs from simultaneous chest band respiratory signal using agreement method
    if strcmp(up.paramSet.ref_method, 'band_agree')
        % Extract respiratory signals
        ext_sig = extract_resp_sigs(data, subj, up);
        % Determine SNRs
        snr_sig = calc_snrs(ext_sig, subj, wins, up);
        clear ext_sig
        % LPF to exclude freqs above resp
        lpf_sig = lpf_to_exclude_resp(snr_sig, subj, up);
        clear snr_sig
        % setup
        no_wins = length(wins.t_start);
        temp_t = mean([wins.t_start(:)' ; wins.t_end(:)']); temp_t = temp_t(:);
        rr_ref.v = nan(length(wins.t_start),1);
        rr_ref.snr_log = false(length(wins.t_start),1);
        % cycle through each window
        for win_no = 1 : no_wins
            % select data for this window
            rel_els = find(lpf_sig.t >= wins.t_start(win_no) & lpf_sig.t <= wins.t_end(win_no));
            rel_data.t = lpf_sig.t(rel_els);
            rel_data.v = lpf_sig.v(rel_els);
            % interpolate data to be at fixed time values
            downsample_freq = 5;
            interp_data.t = wins.t_start(win_no): (1/downsample_freq) : wins.t_end(win_no);
            interp_data.v = interp1(rel_data.t, rel_data.v, interp_data.t, 'linear');
            % get rid of nans
            interp_data.v(isnan(interp_data.v)) = median(interp_data.v(~isnan(interp_data.v)));
            % normalise data
            rel_sig.v = (interp_data.v - mean(interp_data.v))/std(interp_data.v);
            rel_sig.t = interp_data.t;
            rel_sig.snr = lpf_sig.snr;
            rel_sig.fs = downsample_freq;
            clear rel_data interp_data
            % perform combined CtO and FFT analysis:
            % CtO
            rr_cto = ref_cto(rel_sig, up);
            % FFT
            rr_fft = ref_fft(rel_sig, downsample_freq, up);
            % Final RR for this window
            rrs = [rr_cto, rr_fft];
            if range(rrs) < 2
                rr_ref.v(win_no,1) = mean(rrs);
                rr_ref.snr_log(win_no,1) = true;
            else
                rr_ref.v(win_no,1) = nan;
                rr_ref.snr_log(win_no,1) = false;
            end
            
            clear rel_sig rr_cto rr_fft rrs rel_data interp_data downsample_freq rel_els
            
        end
        clear no_wins s wins win_no temp_t lpf_sig
        
        %% Save ref RRs to file
        save_or_append_data
        clear rr_ref
    end
    
end

end

function rr_ref = find_rr_ref_from_ref_rrs(wins, data, subj)
rr_ref.t = mean([wins.t_start(:)' ; wins.t_end(:)']); rr_ref.t = rr_ref.t(:);
rr_ref.v = nan(length(rr_ref.t),1);
% check to see if there are impedance numerics for this subject
if strcmp(fieldnames(data(subj).ref.params), 'rr')
    % if so find the mean in each window
    rel_data = data(subj).ref.params.rr;
    for win_no = 1 : length(wins.t_start)
        rel_els = rel_data.t >= wins.t_start(win_no) & rel_data.t < wins.t_end(win_no);
        rr_ref.v(win_no) = nanmean(rel_data.v(rel_els));
    end
end
end

function rr_ref = find_rr_ref_from_ref_breaths(wins, data, subj, up)
rel_breath_timings = data(subj).ref.breaths.t;

rr_ref.t = mean([wins.t_start(:)' ; wins.t_end(:)']); rr_ref.t = rr_ref.t(:);
rr_ref.v = nan(length(wins.t_start),1);
for win_no = 1 : length(rr_ref.t)
    win_breaths = rel_breath_timings >= wins.t_start(win_no) ...
        & rel_breath_timings < wins.t_end(win_no);
    if sum(win_breaths) == 0
        rr_ref.v(win_no) = NaN;
    else
        ave_breath_duration = range(rel_breath_timings(win_breaths))/(sum(win_breaths)-1);
        rr_ref.v(win_no) = 60/ave_breath_duration;
        % rr.v(win_no) = mean(60./diff(rr_breaths));   % doesn't work as outliers have a big effect (eg spurious breath detections)
    end
end

% in the absence of snrs, assume they are all good:
ideal_snr = 10;
rr_ref_snr = ideal_snr*ones(length(rr_ref.v),1);
rr_ref.snr_log = logical(rr_ref_snr > up.paramSet.paw_snr_thresh);

% mark those which have implausible RRs as bad:
bad_els = rr_ref.v>up.paramSet.rr_range(2) | rr_ref.v<up.paramSet.rr_range(1);
rr_ref.snr_log(bad_els) = false;
end

function new_sig = extract_resp_sigs(data, subj, up)

%% See which resp signals are present:
if sum(strcmp(up.paramSet.ref_method(1:3), 'imp'))
    % select impedance:
    if strcmp(fieldnames(data(subj).ref.resp_sig), 'imp')
        imp.v = data(subj).ref.resp_sig.imp.v;
        imp.fs = data(subj).ref.resp_sig.imp.fs;
        imp.t = (1/imp.fs)*(1:length(imp.v));
        new_sig = imp;
    elseif strcmp(fieldnames(data(subj).ref.resp_sig), 'unknown')
        unk.v = data(subj).ref.resp_sig.unknown.v;
        unk.fs = data(subj).ref.resp_sig.unknown.fs;
        unk.t = (1/unk.fs)*(1:length(unk.v));
        new_sig = unk;
    end
        
elseif sum(strcmp(up.paramSet.ref_method, 'paw'))
    % select paw:
    paw.v = data(subj).ref.resp_sig.paw.v;
    paw.fs = data(subj).ref.resp_sig.paw.fs;
    paw.t = (1/paw.fs)*(1:length(paw.v));
    % store
    new_sig = paw;
end
if sum(strcmp(up.paramSet.ref_method, 'co2'))
    % select co2:
    co2.v = data(subj).ref.resp_sig.co2.v;
    co2.fs = data(subj).ref.resp_sig.co2.fs;
    co2.t = (1/co2.fs)*(1:length(co2.v));
    % store
    new_sig = co2;
elseif sum(strcmp(up.paramSet.ref_method(1:3), 'ban'))
    % select chest band:
    band.v = data(subj).ref.resp_sig.band.v;
    band.fs = data(subj).ref.resp_sig.band.fs;
    band.t = (1/band.fs)*(1:length(band.v));
    new_sig = band; 
end
end

function sig = calc_snrs(sig, subj, wins, up)

sig.snr = nan(length(wins.t_start),1);
for win_no = 1 : length(wins.t_start)
    % select data for this window
    rel_els = find(sig.t >= wins.t_start(win_no) & sig.t <= wins.t_end(win_no));
    rel_data.t = sig.t(rel_els);
    rel_data.v = sig.v(rel_els);
    
    if strcmp(up.paramSet.ref_method, 'paw')
        % calc snr
        sig.snr(win_no) = snr(rel_data.v);
    end
end
end

function lpf_sig = lpf_to_exclude_resp(sig, subj, up)

%% Window signal to reduce edge effects
duration_of_signal = sig.t(end) - sig.t(1);
prop_of_win_in_outer_regions = 2*up.paramSet.tukey_win_duration_taper/duration_of_signal;
tukey_win = tukeywin(length(sig.v), prop_of_win_in_outer_regions);
d_s_win = sig;    % copy time and fs
d_s_win.v = detrend(sig.v(:)).*tukey_win(:);

%% LPF to remove freqs above resp
lpf_sig.t = d_s_win.t;
lpf_sig.v = lp_filter_signal_to_remove_freqs_above_resp(d_s_win.v, d_s_win.fs, up, 'ref_rr');
lpf_sig.fs = d_s_win.fs;
lpf_sig.snr = sig.snr;
% NB: if you use the e_vlf signal then the freqs below resp have already been removed.

end

function [rr_ref_val, rr_ref_snr, breath_times] = pos_grad_thresh(rel_sig, wins, win_no, up, sig_name)

% Identify peak detection threshold
if strcmp(up.paramSet.ref_method, 'imp')
    thresh = up.paramSet.resp_sig_thresh.imp;
    rr_ref_snr = true;
elseif strcmp(up.paramSet.ref_method, 'paw')
    thresh = up.paramSet.resp_sig_thresh.paw;
    rr_ref_snr = logical(rel_sig.snr(win_no) > up.paramSet.paw_snr_thresh);
end

% Find breath times
breath_times = [];
for el = 1 : (length(rel_sig.v)-1)
    if rel_sig.v(el) < thresh & rel_sig.v(el+1) > thresh
        breath_times = [breath_times, mean([rel_sig.t(el), rel_sig.t(el+1)])];
    end
end

% Find RR
win_breaths = breath_times >= wins.t_start(win_no) ...
    & breath_times < wins.t_end(win_no);
if sum(win_breaths) == 0
    rr_ref_val = NaN;
else
    ave_breath_duration = range(breath_times(win_breaths))/(sum(win_breaths)-1);
    rr_ref_val = 60/ave_breath_duration;
end

end

function rr_cto = ref_cto(sum_both, up)

% identify peaks
diffs_on_left_of_pt = diff(sum_both.v); diffs_on_left_of_pt = diffs_on_left_of_pt(1:(end-1)); diffs_on_left_of_pt = logical(diffs_on_left_of_pt>0);
diffs_on_right_of_pt = diff(sum_both.v); diffs_on_right_of_pt = diffs_on_right_of_pt(2:end); diffs_on_right_of_pt = logical(diffs_on_right_of_pt<0);
peaks = find(diffs_on_left_of_pt & diffs_on_right_of_pt)+1;
% identify troughs
diffs_on_left_of_pt = diff(sum_both.v); diffs_on_left_of_pt = diffs_on_left_of_pt(1:(end-1)); diffs_on_left_of_pt = logical(diffs_on_left_of_pt<0);
diffs_on_right_of_pt = diff(sum_both.v); diffs_on_right_of_pt = diffs_on_right_of_pt(2:end); diffs_on_right_of_pt = logical(diffs_on_right_of_pt>0);
troughs = find(diffs_on_left_of_pt & diffs_on_right_of_pt)+1;
% define threshold
q3 = quantile(sum_both.v(peaks), 0.75);
thresh = 0.2*q3;
% find relevant peaks and troughs
extrema = sort([peaks(:); troughs(:)]);
rel_peaks = peaks(sum_both.v(peaks) > thresh);
rel_troughs = troughs(sum_both.v(troughs) < 0);

% find valid breathing cycles
% valid cycles start with a peak:
valid_cycles = zeros(length(rel_peaks)-1,1);
cycle_durations = nan(length(rel_peaks)-1,1);
for peak_no = 1 : (length(rel_peaks)-1)
    
    % valid if there is only one rel_trough between this peak and the
    % next
    cycle_rel_troughs = rel_troughs(rel_troughs > rel_peaks(peak_no) & rel_troughs < rel_peaks(peak_no+1));
    if length(cycle_rel_troughs) == 1
        valid_cycles(peak_no) = 1;
        cycle_durations(peak_no) = sum_both.t(rel_peaks(peak_no+1)) - sum_both.t(rel_peaks(peak_no));
    end
    
end

% Calc RR
if sum(valid_cycles) == 0
    rr_cto = nan;
else
    % Using average breath length
    ave_breath_duration = nanmean(cycle_durations);
    rr_cto = 60/ave_breath_duration;
end

end

function rr_zex = ref_zex(sum_both, up)

%% identify individual breaths from the raw signal using +ve grad zero-crossing detection:
val_on_left_of_pt = sum_both.v(1:(end-1)); left_log = logical(val_on_left_of_pt < 0);
val_of_pt = sum_both.v(2:end); pt_log = logical(val_of_pt >= 0);
breaths = find(left_log & pt_log)+1;
if isempty(breaths)
    rr_zex = nan;
    return
end

%% Calc RR
% Only using time period spanning a whole number of breaths
win_length = sum_both.t(breaths(end)) - sum_both.t(breaths(1));
rr_zex = 60*(length(breaths)-1)/win_length;

end

function rr_wch = ref_wch(sum_both, downsample_freq, up)

segLen = 2^nextpow2(12*downsample_freq);
noverlap = segLen/2;
[data.power, data.freqs] = pwelch(sum_both.v,segLen,noverlap, [], downsample_freq);

% Find spectral peak
[rr_wch, ~, ~] = find_spectral_peak(data, up);

end

function rr_fft = ref_fft(sum_both, downsample_freq, up)

% Find FFT
WINLENGTH = length(sum_both.v);
NFFT = 2^nextpow2(WINLENGTH);
HAMMWIN = hamming(WINLENGTH);
HAMMWIN = HAMMWIN(:);
f_nyq = downsample_freq/2;
FREQS = f_nyq.*linspace(0, 1, NFFT/2+1);            % Array of correspondent FFT bin frequencies, in BR (RPM)
WINDATA = detrend(sum_both.v(:));                      % Remove the LSE straight line from the data
WINDATA = WINDATA .* HAMMWIN;
myFFT = fft(WINDATA, NFFT);
myFFT = myFFT(1 : NFFT/2 + 1);
myFFT = 2.*abs(myFFT/NFFT);
psdx = (1/(downsample_freq*NFFT)) * abs(myFFT).^2;
psdx(2:end-1) = 2*psdx(2:end-1);
power = 10*log10(psdx); power = power(:);
freqs = FREQS; freqs = freqs(:);

% Find respiratory peak
freq_range = up.paramSet.rr_range/60;
cand_els = zeros(length(power),1);
for s = 2 : (length(power)-1)
    if power(s) > power(s-1) & power(s) > power(s+1) & freqs(s) > freq_range(1) & freqs(s) < freq_range(2)
        cand_els(s) = 1;
    end
end
cand_els = find(cand_els);

[~, r_el] = max(power(cand_els));
r_el = cand_els(r_el);
r_freq = freqs(r_el);
if ~isempty(r_freq)
    rr_fft = 60*r_freq;
else
    rr_fft = nan;
end

end

function [qual, rr_cto, prop_norm_dur, prop_bad_breaths, R2, R2min] = ref_cto_mod(rel_sig, up, save_name)

rel_sig.t_n = rel_sig.t-rel_sig.t(1);
rel_sig.v = -1*detrend(rel_sig.v);

%% Identify relevant peaks and troughs

% identify peaks
diffs_on_left_of_pt = diff(rel_sig.v); diffs_on_left_of_pt = diffs_on_left_of_pt(1:(end-1)); diffs_on_left_of_pt = logical(diffs_on_left_of_pt>0);
diffs_on_right_of_pt = diff(rel_sig.v); diffs_on_right_of_pt = diffs_on_right_of_pt(2:end); diffs_on_right_of_pt = logical(diffs_on_right_of_pt<0);
peaks = find(diffs_on_left_of_pt & diffs_on_right_of_pt)+1;
% identify troughs
diffs_on_left_of_pt = diff(rel_sig.v); diffs_on_left_of_pt = diffs_on_left_of_pt(1:(end-1)); diffs_on_left_of_pt = logical(diffs_on_left_of_pt<0);
diffs_on_right_of_pt = diff(rel_sig.v); diffs_on_right_of_pt = diffs_on_right_of_pt(2:end); diffs_on_right_of_pt = logical(diffs_on_right_of_pt>0);
troughs = find(diffs_on_left_of_pt & diffs_on_right_of_pt)+1;
% define peaks threshold
q3 = quantile(rel_sig.v(peaks), 0.75);
thresh = 0.2*q3;
% find relevant peaks
rel_peaks = peaks(rel_sig.v(peaks) > thresh);
% define troughs threshold
q3t = quantile(rel_sig.v(troughs), 0.25);
thresh = 0.2*q3t;
% find relevant troughs
rel_troughs = troughs(rel_sig.v(troughs) < thresh);

%% find valid breathing cycles
% exclude peaks which aren't the highest between a pair of consecutive
% troughs:
invalid_peaks = zeros(length(rel_peaks),1);
for trough_pair_no = 1 : (length(rel_troughs)-1)
    
    % identify peaks between this pair of troughs
    cycle_rel_peak_els = find(rel_peaks > rel_troughs(trough_pair_no) & rel_peaks < rel_troughs(trough_pair_no+1));
    cycle_rel_peaks = rel_peaks(cycle_rel_peak_els);
    if length(cycle_rel_peaks) > 1
        [~, rel_el] = max(rel_sig.v(cycle_rel_peaks));
        bad_rel_peaks_els = setxor(1:length(cycle_rel_peak_els), rel_el);
        invalid_peaks(cycle_rel_peak_els(bad_rel_peaks_els)) = 1;
    end
end
rel_peaks = rel_peaks(~invalid_peaks);

% if there is more than one initial peak (i.e. before the first trough) then take the highest:
initial_peaks = find(rel_peaks < rel_troughs(1));
other_peaks = find(rel_peaks >= rel_troughs(1));
if length(initial_peaks)>1
    [~, rel_initial_peak] = max(rel_sig.v(rel_peaks(initial_peaks)));
    rel_peaks = rel_peaks([rel_initial_peak, other_peaks]);
end

% valid cycles start with a peak:
valid_cycles = false(length(rel_peaks)-1,1);
cycle_durations = nan(length(rel_peaks)-1,1);

for peak_no = 2 : length(rel_peaks)
    
    % exclude if there isn't a rel trough between this peak and the
    % previous one
    cycle_rel_troughs = rel_troughs(rel_troughs > rel_peaks(peak_no-1) & rel_troughs < rel_peaks(peak_no));
    if length(cycle_rel_troughs) ~= 0
        valid_cycles(peak_no-1) = true;
        cycle_durations(peak_no-1) = rel_sig.t(rel_peaks(peak_no)) - rel_sig.t(rel_peaks(peak_no-1));
    end
end
valid_cycle_durations = cycle_durations(valid_cycles);

% Calc RR
if isempty(valid_cycle_durations)
    rr_cto = nan;
else
    % Using average breath length
    ave_breath_duration = mean(valid_cycle_durations);
    rr_cto = 60/ave_breath_duration;
end

%% Resiratory SQI

if isnan(rr_cto)
    qual = false;
    prop_norm_dur = 0;
    prop_bad_breaths = 100;
    R2 = 0;
    R2min = 0;
else
    
    %find mean breath-to-breath interval to define size of template
    rr=floor(mean(diff(rel_peaks)));
    ts=[];
    j=find(rel_peaks>rr/2);
    l=find(rel_peaks+floor(rr/2)<length(rel_sig.v));
    new_rel_peaks = rel_peaks(j(1):l(end));
    if isempty(new_rel_peaks)
        qual = false;
        prop_norm_dur = 0;
        prop_bad_breaths = 100;
        R2 = 0;
        R2min = 0;
        return
    else
        %find breaths
        for k=1:length(new_rel_peaks)
            t=rel_sig.v(new_rel_peaks(k)-floor(rr/2):new_rel_peaks(k)+floor(rr/2));
            tt=t/norm(t); tt = tt(:)';
            ts=[ts;tt];
        end
    end
    
    %find ave template
    if size(ts,1) > 1
        avtempl=mean(ts,1);
    else
        avtempl=nan(size(ts));
    end
    
    %now calculate correlation for every beat in this window
    r2 = nan(size(ts,1),1);
    for k=1:size(ts,1)
        r2(k)=corr2(avtempl,ts(k,:));
    end
    %calculate mean correlation coefficient
    R2=mean(r2);
    R2min = std(valid_cycle_durations)/mean(valid_cycle_durations);
    %peak_heights = rel_sig.v(rel_troughs);
    %R2min = std(peak_heights)/mean(peak_heights);
    
    % calculate number of abnormal breath durations
    median_dur = median(valid_cycle_durations);
    temp = valid_cycle_durations > (1.5*median_dur) | valid_cycle_durations < (0.5*median_dur);
    prop_bad_breaths = 100*sum(temp)/length(temp);
    
    % find prop of window taken up by normal breath durations
    norm_dur = sum(valid_cycle_durations(~temp));
    win_length = rel_sig.t(end) - rel_sig.t(1);
    prop_norm_dur = 100*norm_dur/win_length;
    
    % determine whether this window is high or low quality
    if prop_norm_dur > 60 && prop_bad_breaths < 15 && R2 >= 0.75 && R2min < 0.25
        qual = true;
    else
        qual = false;
    end
    
end

%% Plot template and inidividual beats
save_name = 'no';
if ~strcmp(save_name, 'no') && ~isnan(rr_cto)
    
    paper_size = [12, 8];
    figure('Position', [50, 50, 100*paper_size(1), 100*paper_size(2)], 'Color',[1 1 1])
    lwidth1 = 3; lwidth2 = 2; ftsize = 22;
    % plot signal
    subplot(2,2,[1,2]), plot(rel_sig.t-rel_sig.t(1), rel_sig.v, 'LineWidth', lwidth2), hold on
    plot(rel_sig.t(rel_peaks(logical([valid_cycles; 1])))-rel_sig.t(1), rel_sig.v(rel_peaks(logical([valid_cycles; 1]))), '.r', 'MarkerSize', 20)
    %plot(rel_sig.t(new_rel_peaks)-rel_sig.t(1), rel_sig.v(new_rel_peaks), '.r', 'MarkerSize', 20)
    %plot(rel_sig.t(rel_troughs)-rel_sig.t(1), rel_sig.v(rel_troughs), '.k', 'MarkerSize', 20)
    xlim([0, rel_sig.t(end)-rel_sig.t(1)])
    xlabel('Time [s]', 'FontSize', ftsize)
    ylab=ylabel('Imp', 'FontSize', ftsize, 'Rotation', 0);
    set(ylab, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
    set(gca, 'FontSize', ftsize, 'YTick', [])
    % plot template
    time = 0:(length(avtempl)-1); time = time./rel_sig.fs;
    subplot(2,2,3), hold on,
    for beat_no = 1 : size(ts,1)
        plot(time, ts(beat_no,:), 'color', 0.7*[1 1 1], 'LineWidth', lwidth2)
    end
    plot(time, avtempl, 'r', 'LineWidth', lwidth1)
    set(gca, 'YTick', [])
    xlabel('Time [s]', 'FontSize', ftsize)
    xlim([0, time(end)])
    ylab=ylabel('Imp', 'FontSize', ftsize, 'Rotation', 0);
    set(ylab, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
    set(gca, 'FontSize', ftsize)
    %set ylim
    rang = range(ts(:));
    ylim([min(ts(:))-0.1*rang, max(ts(:))+0.1*rang]);
    annotation('textbox',[0.5, 0.1, 0.1,0.1],'String',{['R2 = ' num2str(R2, 2)] , ['prop breaths bad = ' num2str(prop_bad_breaths, 2) '%'], ['prop dur good = ' num2str(prop_norm_dur,2) '%']}, 'FontSize', ftsize, 'LineStyle', 'None')
    if qual
        annotation('textbox',[0.75, 0.2, 0.1,0.1],'String','High Quality', 'Color', 'b', 'FontSize', ftsize, 'LineStyle', 'None')
    else
        annotation('textbox',[0.75, 0.2, 0.1,0.1],'String','Low Quality', 'Color', 'r', 'FontSize', ftsize, 'LineStyle', 'None')
    end
    savepath = [up.paths.plots_save_folder, save_name];
    PrintFigs(gcf, paper_size, savepath, up)
    close all
end
end

function calc_spec(sig, downsample_freq, up)

close all

% Find FFT
WINLENGTH = length(sig.v);
NFFT = 2^nextpow2(WINLENGTH);
HAMMWIN = hamming(WINLENGTH);
HAMMWIN = HAMMWIN(:);
f_nyq = downsample_freq/2;
FREQS = f_nyq.*linspace(0, 1, NFFT/2+1);            % Array of correspondent FFT bin frequencies, in BR (RPM)
WINDATA = detrend(sig.v(:));                      % Remove the LSE straight line from the data
WINDATA = WINDATA .* HAMMWIN;
myFFT = fft(WINDATA, NFFT);
myFFT = myFFT(1 : NFFT/2 + 1);
myFFT = 2.*abs(myFFT/NFFT);
psdx = (1/(downsample_freq*NFFT)) * abs(myFFT).^2;
psdx(2:end-1) = 2*psdx(2:end-1);
power = 10*log10(psdx); power = power(:);
freqs = FREQS; freqs = freqs(:);

plot(freqs, power)

end

function PrintFigs(h, paper_size, savepath, up)
set(h,'PaperUnits','inches');
set(h,'PaperSize', [paper_size(1), paper_size(2)]);
set(h,'PaperPosition',[0 0 paper_size(1) paper_size(2)]);
% print(h,'-dpdf',savepath)
print(h,'-dpng',savepath)

% % you need to download 'export_fig' from:
% % http://uk.mathworks.com/matlabcentral/fileexchange/23629-export-fig
% export_fig_dir_path = 'C:\Users\pc13\Documents\GitHub\phd\Tools\Other Scripts\export_fig\';
% addpath(export_fig_dir_path)
% export_fig(savepath, '-eps')

close all
end