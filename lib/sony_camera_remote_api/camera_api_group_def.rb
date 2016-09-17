module SonyCameraRemoteAPI
  class CameraAPIGroupManager

    # Convert exposure compensation step of ExposureCompensation API group into the real step.
    def self.get_exposure_compensation_step(step)
      case step
        when 1 then 0.33
        when 2 then 0.5
        else 0
      end
    end

    @@api_groups_all = {
      ShootMode:            APIGroup.new(:ShootMode,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                         end_condition: ->(v, r) { r[21]['currentShootMode'] == v },
                                        ),
      # setLiveviewSize API does not exist: we use startLiveviewWithSize API instead.
      LiveviewSize:         APIGroup.new(:LiveviewSize,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         nil,
                                        ),
      ZoomSetting:          APIGroup.new(:ZoomSetting,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['zoom'] },
                                         ->(v, avl, cond) { [{ 'zoom' => v }] },
                                        ),
      TrackingFocus:        APIGroup.new(:TrackingFocus,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['trackingFocus'] },
                                         ->(v, avl, cond) { [{ 'trackingFocus' => v }] },
                                        ),
      ContShootingMode:     APIGroup.new(:ContShootingMode,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['contShootingMode'] },
                                         ->(v, avl, cond) { [{ 'contShootingMode' => v }] },
                                         end_condition: ->(v, r) { r[38]['contShootingMode'] == v },
                                        ),
      ContShootingSpeed:    APIGroup.new(:ContShootingSpeed,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['contShootingSpeed'] },
                                         ->(v, avl, cond) { [{ 'contShootingSpeed' => v }] },
                                         end_condition: ->(v, r) { r[39]['contShootingSpeed'] == v },
                                        ),
      SelfTimer:            APIGroup.new(:SelfTimer,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                        ),
      ExposureMode:         APIGroup.new(:ExposureMode,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                        ),
      FocusMode:            APIGroup.new(:FocusMode,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                        ),
      # Handle parameter value by EV instead of exposure compensation index value.
      ExposureCompensation: APIGroup.new(:ExposureCompensation,
                                         # Get supported exposure compensation Array by EV.
                                         ->(r, cond) do
                                           ev_list = []
                                           r.transpose.each do | max, min, step |
                                             step = get_exposure_compensation_step step
                                             next if step == 0
                                             ev_list << (min..max).map { |e| (e * step).round(1) }
                                           end
                                           ev_list.size == 1 ? ev_list[0] : ev_list
                                         end,
                                         # Get available exposure compensation Array by EV.
                                         ->(r, cond) do
                                           max, min, step = r[1..-1]
                                           step = get_exposure_compensation_step step
                                           (min..max).map { |e| (e * step).round(1) }
                                         end,
                                         # Get current exposure compensation by EV.
                                         ->(r, cond) do
                                           step = cond[25]['stepIndexOfExposureCompensation']
                                           step = get_exposure_compensation_step step
                                           (r[0] * step).round(1)
                                         end,
                                         # Set exposure compensation By index from EV.
                                         ->(v, avl, cond) do
                                           avl.index(v) - avl.index(0)
                                         end,
                                         # Get exposure compensation step.
                                         start_condition: ->(r) do
                                           r[25]['stepIndexOfExposureCompensation'] != nil
                                         end,
                                        ),
      FNumber:              APIGroup.new(:FNumber,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                         end_condition: ->(v, r) { r[27]['currentFNumber'] == v },
                                        ),
      ShutterSpeed:         APIGroup.new(:ShutterSpeed,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                         end_condition: ->(v, r) { r[32]['currentShutterSpeed'] == v },
                                        ),
      IsoSpeedRate:         APIGroup.new(:IsoSpeedRate,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                         end_condition: ->(v, r) { r[29]['currentIsoSpeedRate'] == v },
                                        ),
      # Enable more intuitive parameter format as followings:
      #  * Hash-1 : { 'whiteBalanceMode' => mode, 'colorTemperature' => color-temperature }
      #  * Hash-2 : { whiteBalanceMode: mode, colorTemperature: color-temperature}
      #  * Array (original): [ mode, temperature-enabled-flag, color-temperature ]
      WhiteBalance:         APIGroup.new(:WhiteBalance,
                                         # Get supported white-balance mode by Array of Hash.
                                         #   * delete 'colorTemperatureRange' key if unneeded.
                                         #   * get color temperature list rather than min/max/step.
                                         ->(r, cond) do
                                           mode_temp_list = []
                                           r[0].map do |e|
                                             mt = {}
                                             mt['whiteBalanceMode'] = e['whiteBalanceMode']
                                             if e['colorTemperatureRange'].present?
                                               max, min, step = e['colorTemperatureRange']
                                               mt['colorTemperature'] = (min..max).step(step).to_a
                                             end
                                             mode_temp_list << mt
                                           end
                                           mode_temp_list
                                         end,
                                         # Get available white-balance mode by Array of Hash, almost same as supported-accessor.
                                         ->(r, cond) do
                                           mode_temp_list = []
                                           r[1].map do |e|
                                             mt = {}
                                             mt['whiteBalanceMode'] = e['whiteBalanceMode']
                                             if e['colorTemperatureRange'].present?
                                               max, min, step = e['colorTemperatureRange']
                                               mt['colorTemperature'] = (min..max).step(step).to_a
                                             end
                                             mode_temp_list << mt
                                           end
                                           mode_temp_list
                                         end,
                                         # Get current white-balance mode and temperature by Hash.
                                         # temperature key is deleted if unneeded.
                                         ->(r, cond) do
                                           r[0].delete_if { |k,v| k == 'colorTemperature' and v == -1 }
                                         end,
                                         # Set white-balance mode, converting Hash-1 to Array.
                                         ->(v, avl, cond) do
                                           temp_flag   = v.key?('colorTemperature') ? true : false
                                           temperature = v.key?('colorTemperature') ? v['colorTemperature'] : 0
                                           [v['whiteBalanceMode'], temp_flag, temperature]
                                         end,
                                         # Accept the parameter forms as followings:
                                         # Array and Hash-2 is converted to Hash-1.
                                         preprocess_value: ->(v, arg, cond) do
                                           if v.is_a? Array
                                             ret = {}
                                             ret['whiteBalanceMode'] = v[0]
                                             ret['colorTemperature'] = v[2] if v[1] == true
                                             ret
                                           elsif v.is_a? Hash
                                             Hash[v.map { |k, v| [k.is_a?(Symbol) ? k.to_s : k , v] }]
                                           end
                                         end,
                                         # Check the given value is available by
                                         #   * comparing mode
                                         #   * color temperature value is included in 'colorTemperature' array
                                         #     when Color Temperature mode
                                         check_availability: ->(v, avl, cond) do
                                           # check mode
                                           sel = avl.find {|e| v['whiteBalanceMode'] == e['whiteBalanceMode'] }
                                           return false if sel.nil?

                                           if sel.key? 'colorTemperatureRange'
                                             # temperature
                                             return true if sel['colorTemperature'].include? v['colorTemperature']
                                             false
                                           else
                                             true
                                           end
                                         end,
                                        ),
      # ProgramShift:         APIGroup.new(:ProgramShift,
      #                                    ->(v, cond){ v[0] },
      #                                    ->(v, cond){ v[1] },
      #                                    ->(v, cond){ v[0] },
      #                                    ->(v, avl, cond){ [v] },
      #                                   ),
      FlashMode:            APIGroup.new(:FlashMode,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] }
                                        ),
      # Enable more intuitive parameter format as followings:
      #   * Hash-1 :  { 'aspect' => aspect, 'size' => size }
      #   * Hash-2 :  { aspect: aspect, size: size }
      #   * Array (original) : [ aspect, size ]
      # make setStillSize accept Hash as parameter, because getSupported/AvailableStillSize returns Hash
      StillSize:            APIGroup.new(:StillSize,
                                         # Get supported still size and aspect by Array of Hash.
                                         ->(r, cond) { r[0] },
                                         # Get available still size and aspect by Array of Hash.
                                         ->(r, cond) { r[1] },
                                         # Get current still size and aspect by Hash.
                                         ->(r, cond) { r[0] },
                                         # Set still size and aspect, converting Hash-1 to Array.
                                         ->(v, avl, cond) { [v['aspect'], v['size']] },
                                         # Accept the parameter forms as followings:
                                         # Array and Hash-2 is converted to Hash-1.
                                         preprocess_value: ->(v, arg, cond) do
                                           if v.is_a? Array
                                             ret = {}
                                             ret['aspect'] = v[0]
                                             ret['size'] = v[1]
                                             ret
                                           elsif v.is_a? Hash
                                             Hash[v.map { |k, v| [k.is_a?(Symbol) ? k.to_s : k , v] }]
                                           end
                                         end,
                                        ),
      StillQuality:         APIGroup.new(:StillQuality,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['stillQuality'] },
                                         ->(v, avl, cond) { [{ 'stillQuality' => v }] },
                                        ),
      PostviewImageSize:    APIGroup.new(:PostviewImageSize,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                        ),
      MovieFileFormat:      APIGroup.new(:MovieFileFormat,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['movieFileFormat'] },
                                         ->(v, avl, cond) { [{ 'movieFileFormat' => v }] },
                                         end_condition: ->(v, r) { r[45]['movieFileFormat'] == v },
                                        ),
      MovieQuality:         APIGroup.new(:MovieQuality,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                         end_condition: ->(v, r) { r[13]['currentMovieQuality'] == v },
                                        ),
      SteadyMode:           APIGroup.new(:SteadyMode,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                        ),
      ViewAngle:            APIGroup.new(:ViewAngle,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                        ),
      SceneSelection:       APIGroup.new(:SceneSelection,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['scene'] },
                                         ->(v, avl, cond) { [{ 'scene' => v }] },
                                        ),
      ColorSetting:         APIGroup.new(:ColorSetting,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['colorSetting'] },
                                         ->(v, avl, cond) { [{ 'colorSetting' => v }] },
                                        ),
      IntervalTime:         APIGroup.new(:IntervalTime,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['intervalTimeSec'] },
                                         ->(v, avl, cond) { [{ 'intervalTimeSec' => v }] },
                                        ),
      LoopRecTime:          APIGroup.new(:LoopRecTime,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['loopRecTimeMin'] },
                                         ->(v, avl, cond) { [{ 'loopRecTimeMin' => v }] },
                                        ),
      WindNoiseReduction:   APIGroup.new(:WindNoiseReduction,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['windNoiseReduction'] },
                                         ->(v, avl, cond) { [{ 'windNoiseReduction' => v }] },
                                        ),
      AudioRecording:       APIGroup.new(:AudioRecording,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['audioRecording'] },
                                         ->(v, avl, cond) { [{ 'audioRecording' => v }] },
                                        ),
      FlipSetting:          APIGroup.new(:FlipSetting,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['flip'] },
                                         ->(v, avl, cond) { [{ 'flip' => v }] },
                                        ),
      TvColorSystem:        APIGroup.new(:TvColorSystem,
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['candidate'] },
                                         ->(r, cond) { r[0]['tvColorSystem'] },
                                         ->(v, avl, cond) { [{ 'tvColorSystem' => v }] },
                                        ),
      # 'cameraFunctionResult' does not work depending on the timing of setCameraFunction call...
      CameraFunction:       APIGroup.new(:CameraFunction,
                                         ->(r, cond) { r[0] },
                                         ->(r, cond) { r[1] },
                                         ->(r, cond) { r[0] },
                                         ->(v, avl, cond) { [v] },
                                         end_condition: ->(v, r) do
                                           # r[15]['cameraFunctionResult'] == 'Success'
                                           r[12]['currentCameraFunction'] == v
                                         end
                                        ),
      InfraredRemoteControl: APIGroup.new(:InfraredRemoteControl,
                                          ->(r, cond) { r[0]['candidate'] },
                                          ->(r, cond) { r[0]['candidate'] },
                                          ->(r, cond) { r[0]['infraredRemoteControl'] },
                                          ->(v, avl, cond) { [{ 'infraredRemoteControl' => v }] },
                                        ),
      AutoPowerOff:         APIGroup.new(:AutoPowerOff,
                                          ->(r, cond) { r[0]['candidate'] },
                                          ->(r, cond) { r[0]['candidate'] },
                                          ->(r, cond) { r[0]['autoPowerOff'] },
                                          ->(v, avl, cond) { [{ 'autoPowerOff' => v }] },
                                        ),
      BeepMode:             APIGroup.new(:BeepMode,
                                          ->(r, cond) { r[0] },
                                          ->(r, cond) { r[1] },
                                          ->(r, cond) { r[0] },
                                          ->(v, avl, cond) { [v] },
                                        ),
    }

  end
end



