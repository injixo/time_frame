require 'active_support'
require 'active_support/core_ext'

# Avoid i18n deprecation warning
I18n.enforce_available_locales = false

require 'time_frame/time_frame_splitter'
require 'time_frame/time_frame_covered'
require 'time_frame/time_frame_overlaps'
require 'time_frame/time_frame_uniter'

require 'time_frame/time_frame'
