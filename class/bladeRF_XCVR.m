%%
% bladeRF_XCVR - Transceiver object used by the bladeRF MATLAB wrapper.
%
% Do not use this directly.
%

%
% Copyright (c) 2015 Nuand LLC
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
%

%% Control and configuration of transceiver properties
classdef bladeRF_XCVR < handle

    properties(SetAccess = immutable)
        bladerf
        module
        direction
    end

    properties(SetAccess = private)
        running         % Denotes whether or not the module is enabled to stream samples
        timestamp       % Provides a coarse readback of the timestamp counter
    end

    properties
        config          % Stream configuration
        corrections     % IQ corrections
    end

    properties(Dependent = true)
        samplerate      % Samplerate must be between 160kHz and 40MHz
        frequency       % Frequency must be between 240M and 3.8G
        bandwidth       % Bandwidth is discrete
        vga1            % VGA1
        vga2            % VGA2
        lna             % LNA Gain (applicable to RX only)
    end

    properties(Access={?bladeRF})
        sob = true      % TX Start of Burst (Applicable to TX only)
        eob = false     % TX end-of-burst flag (Applicable to TX only)
    end

    methods
        %% Property handling

        % Samplerate
        function set.samplerate(obj, val)
            % Create the holding structures
            rate = libstruct('bladerf_rational_rate');
            actual = libstruct('bladerf_rational_rate');

            % Requested rate
            rate.integer = floor(val);
            [rate.num, rate.den] = rat(mod(val,1));

            % Set the samplerate
            [status, ~, ~, actual] = calllib('libbladeRF', 'bladerf_set_rational_sample_rate', obj.bladerf.device, obj.module, rate, rate);
            bladeRF.check_status('bladerf_set_rational_sample_rate', status);

            %fprintf('Set %s samplerate. Requested: %d + %d/%d, Actual: %d + %d/%d\n', ...
            %        obj.direction, ...
            %        rate.integer, rate.num, rate.den, ...
            %        actual.integer, actual.num, actual.den);
        end

        function samplerate_val = get.samplerate(obj)
            rate = libstruct('bladerf_rational_rate');
            rate.integer = 0;
            rate.num = 0;
            rate.den = 1;

            % Get the sample rate from the hardware
            [status, ~, rate] = calllib('libbladeRF', 'bladerf_get_rational_sample_rate', obj.bladerf.device, obj.module, rate);
            bladeRF.check_status('bladerf_get_rational_sample_rate', status);

            %fprintf('Read %s samplerate: %d + %d/%d\n', ...
            %        obj.direction, rate.integer, rate.num, rate.den);

            samplerate_val = rate.integer + rate.num / rate.den;
        end

        % Frequency
        function set.frequency(obj, val)
            [status, ~] = calllib('libbladeRF', 'bladerf_set_frequency', obj.bladerf.device, obj.module, val);
            bladeRF.check_status('bladerf_set_frequency', status);

            %fprintf('Set %s frequency: %f\n', obj.direction, val);
        end

        function freq_val = get.frequency(obj)
            freq_val = uint32(0);
            [status, ~, freq_val] = calllib('libbladeRF', 'bladerf_get_frequency', obj.bladerf.device, obj.module, freq_val);
            bladeRF.check_status('bladerf_get_frequency', status);

            %fprintf('Read %s frequency: %f\n', obj.direction, freq_val);
        end

        % Configures the LPF bandwidth on the associated module
        function set.bandwidth(obj, val)
            actual = uint32(0);
            [status, ~, actual] = calllib('libbladeRF', 'bladerf_set_bandwidth', obj.bladerf.device, obj.module, val, actual);
            bladeRF.check_status('bladerf_set_bandwidth', status);

            %fprintf('Set %s bandwidth. Requested: %f, Actual: %f\n', ...
            %        obj.direction, val, actual)
        end

        % Reads the LPF bandwidth configuration on the associated module
        function bw_val = get.bandwidth(obj)
            bw_val = uint32(0);
            [status, ~, bw_val] = calllib('libbladeRF', 'bladerf_get_bandwidth', obj.bladerf.device, obj.module, bw_val);
            bladeRF.check_status('bladerf_get_bandwidth', status);

            %fprintf('Read %s bandwidth: %f\n', obj.direction, bw_val);
        end

        % Configures the gain of VGA1
        function set.vga1(obj, val)
            if strcmpi(obj.direction,'RX') == true
                [status, ~] = calllib('libbladeRF', 'bladerf_set_rxvga1', obj.bladerf.device, val);
            else
                [status, ~] = calllib('libbladeRF', 'bladerf_set_txvga1', obj.bladerf.device, val);
            end

            bladeRF.check_status('bladerf_set_vga1', status);

            %fprintf('Set %s VGA1: %d\n', obj.direction, val);
        end

        % Reads the current VGA1 gain configuration
        function val = get.vga1(obj)
            val = int32(0);
            if strcmpi(obj.direction,'RX') == true
                [status, ~, val] = calllib('libbladeRF', 'bladerf_get_rxvga1', obj.bladerf.device, val);
            else
                [status, ~, val] = calllib('libbladeRF', 'bladerf_get_txvga1', obj.bladerf.device, val);
            end

            bladeRF.check_status('bladerf_get_vga1', status);

            %fprintf('Read %s VGA1: %d\n', obj.direction, val);
        end

        % Configures the gain of VGA2
        function set.vga2(obj, val)
            if strcmpi(obj.direction,'RX') == true
                [status, ~] = calllib('libbladeRF', 'bladerf_set_rxvga2', obj.bladerf.device, val);
            else
                [status, ~] = calllib('libbladeRF', 'bladerf_set_txvga2', obj.bladerf.device, val);
            end

            bladeRF.check_status('bladerf_set_vga2', status);

            %fprintf('Set %s VGA2: %d\n', obj.direction, obj.vga2);
        end

        % Reads the current VGA2 configuration
        function val = get.vga2(obj)
            val = int32(0);
            if strcmpi(obj.direction,'RX') == true
                [status, ~, val] = calllib('libbladeRF', 'bladerf_get_rxvga2', obj.bladerf.device, val);
            else
                [status, ~, val] = calllib('libbladeRF', 'bladerf_get_txvga2', obj.bladerf.device, val);
            end

            bladeRF.check_status('bladerf_get_vga2', status);

            %fprintf('Read %s VGA2: %d\n', obj.direction, val);
        end

        % Configure the RX LNA gain
        function set.lna(obj, val)
            if strcmpi(obj.direction,'TX') == true
                error('LNA gain is not applicable to the TX path');
            end

            valid_value = true;

            if isnumeric(val)
                switch val
                    case 0
                        lna_val = 'BLADERF_LNA_GAIN_BYPASS';

                    case 3
                        lna_val = 'BLADERF_LNA_GAIN_MID';

                    case 6
                        lna_val = 'BLADERF_LNA_GAIN_MAX';

                    otherwise
                        valid_value = false;
                end
            else
                if strcmpi(val,'bypass')   == true
                    lna_val = 'BLADERF_LNA_GAIN_BYPASS';
                elseif strcmpi(val, 'mid') == true
                    lna_val = 'BLADERF_LNA_GAIN_MID';
                elseif strcmpi(val, 'max') == true
                    lna_val = 'BLADERF_LNA_GAIN_MAX';
                else
                    valid_value = false;
                end
            end

            if valid_value ~= true
                error('Valid LNA values are [''BYPASS'', ''MID'', ''MAX''] or [0, 3, 6], respectively.');
            else
                [status, ~] = calllib('libbladeRF', 'bladerf_set_lna_gain', obj.bladerf.device, lna_val);
                bladeRF.check_status('bladerf_set_lna_gain', status);

                %fprintf('Set RX LNA gain to: %s\n', lna_val);
            end
        end

        % Read current RX LNA gain setting
        function val = get.lna(obj)
            if strcmpi(obj.direction,'TX') == true
                error('LNA gain is not applicable to the TX path');
            end

            val = 0;
            [status, ~, lna] = calllib('libbladeRF', 'bladerf_get_lna_gain', obj.bladerf.device, val);
            bladeRF.check_status('bladerf_get_lna_gain', status);

            if strcmpi(val, 'BLADERF_LNA_GAIN_BYPASS') == true
                val = 'BYPASS';
            elseif strcmpi(lna, 'BLADERF_LNA_GAIN_MID') == true
                val = 'MID';
            elseif strcmpi(lna, 'BLADERF_LNA_GAIN_MAX') == true
                val = 'MAX';
            else
                val = 'UNKNOWN';
            end

            %fprintf('Got RX LNA gain: %s\n', val);
        end

        % Read the timestamp counter from the associated module
        function val = get.timestamp(obj)
            val = uint64(0);
            [status, ~, val] = calllib('libbladeRF', 'bladerf_get_timestamp', obj.bladerf.device, obj.module, val);
            bladeRF.check_status('bladerf_get_timestamp', status);
        end

        % Constructor
        function obj = bladeRF_XCVR(dev, dir)
            if strcmpi(dir,'RX') == false && strcmpi(dir,'TX') == false
                error('Invalid direction specified');
            end

            % Set the direction of the transceiver
            obj.direction = dir;
            obj.bladerf = dev;
            if strcmpi(dir,'RX') == true
                obj.module = 'BLADERF_MODULE_RX';
            else
                obj.module = 'BLADERF_MODULE_TX';
            end

            % Setup defaults
            obj.config = bladeRF_StreamConfig;
            obj.samplerate = 3e6;
            obj.frequency = 1.0e9;
            obj.bandwidth = 1.5e6;

            if strcmpi(dir, 'RX') == true
                obj.vga1 = 30;
                obj.vga2 = 0;
                obj.lna = 'MAX';
            else
                obj.vga1 = -8;
                obj.vga2 = 16;
            end

            obj.corrections = bladeRF_IQCorr(dev, obj.module, 0, 0, 0, 0);
            obj.running = false;
        end

        % Configure stream and enable module
        function start(obj)
            %fprintf('Starting %s stream.\n', obj.direction);

            obj.running = true;
            obj.config.lock();

            % If we're starting up a TX module, reset our cached EOB/SOB
            % flags so that we can internally take care of these if the
            % user doesn't want to worry about them.
            if strcmpi(obj.direction,'TX') == true
                obj.sob = true;
                obj.eob = false;
            end

            % Configure the sync config
            [status, ~] = calllib('libbladeRF', 'bladerf_sync_config', ...
                                  obj.bladerf.device, ...
                                  obj.module, ...
                                  'BLADERF_FORMAT_SC16_Q11_META', ...
                                  obj.config.num_buffers, ...
                                  obj.config.buffer_size, ...
                                  obj.config.num_transfers, ...
                                  obj.config.timeout_ms);

            bladeRF.check_status('bladerf_sync_config', status);

            % Enable the module
            [status, ~] = calllib('libbladeRF', 'bladerf_enable_module', ...
                                  obj.bladerf.device, ...
                                  obj.module, ...
                                  true);

            bladeRF.check_status('bladerf_enable_module', status);
        end


        % Stop streaming and disable the module
        function stop(obj)
            %fprintf('Stopping %s module.\n', obj.direction);

            % If the user is trying top stop "mid-burst", we'll want to
            % end the burst to ensure the TX DAC is reset to 0+0j
            if strcmpi(obj.direction,'TX') == true
                if obj.sob == false && obj.eob == false
                    obj.eob = true;
                    obj.bladerf.transmit(0, 0, obj.sob, obj.eob);
                end
            end

            % Disable the module
            [status, ~] = calllib('libbladeRF', 'bladerf_enable_module', ...
                                  obj.bladerf.device, ...
                                  obj.module, ...
                                  false);

            bladeRF.check_status('bladerf_enable_module', status);

            % Unlock the configuration for changing
            obj.config.unlock();
            obj.running = false;
        end
    end
end
