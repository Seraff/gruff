require 'gruff'

class Gruff::VerticalTimeline < Gruff::Base
  # Spacing factor applied between bars
  attr_accessor :bar_spacing, :time_format

  def initialize(*args)
    super
    @spacing_factor = 0.9
    @left_margin = 80
    @has_left_labels = false
    @hide_line_numbers = true
    @time_format = '%H:%M'
    @y_axis_increment = 60*60
  end

  def minimum_value=(value)
    @minimum_value = value.to_i
  end

  def maximum_value=(value)
    @maximum_value = value.to_i
  end

  def draw
    super
    return unless @has_data

    draw_bars
  end

  def spacing_factor=(space_percent)
    raise ArgumentError, 'spacing_factor must be between 0.00 and 1.00' unless (space_percent >= 0 and space_percent <= 1)
    @spacing_factor = (1 - space_percent)
  end

  def data(name, data_points=[], color=nil)
    data_points = Array(data_points) # make sure it's an array
    @data << [name, data_points, color]

    # Set column count if this is larger than previous counts
    @column_count ||= 0
    @column_count += 1

    @has_data = true
  end

  def normalize(force=false)
    if @norm_data.nil? || force
      @norm_data = []
      return unless @has_data

      @data.each do |data_row|
        norm_time_intervals = []
        data_row[DATA_VALUES_INDEX].each do |time_interval|
          if time_interval.nil?
            norm_time_intervals << nil
          else
            norm_time_intervals << time_interval.map{ |time| normalize_value(time) }
          end
        end
        if @show_labels_for_bar_values
          @norm_data << [data_row[DATA_LABEL_INDEX], norm_time_intervals, data_row[DATA_COLOR_INDEX], data_row[DATA_VALUES_INDEX]]
        else
          @norm_data << [data_row[DATA_LABEL_INDEX], norm_time_intervals, data_row[DATA_COLOR_INDEX]]
        end
      end
    end
  end

  def normalize_value(value)
    (value.to_f - @minimum_value.to_f) / @spread
  end

  protected

  def draw_bars
    # Setup spacing.
    #
    # Columns sit side-by-side.
    @bar_spacing ||= @spacing_factor # space between the bars
    @bar_width = @graph_width / @norm_data.length.to_f
    padding = (@bar_width * (1 - @bar_spacing)) / 2

    @d = @d.stroke_opacity 0.0

    @norm_data.each_with_index do |data_row, row_index|
      @d = @d.fill data_row[DATA_COLOR_INDEX]

      data_row[DATA_VALUES_INDEX].each_with_index do |time_interval, point_index|
        # x
        left_x = @graph_left + (@bar_width * row_index) + padding
        right_x = left_x + @bar_width * @bar_spacing

        # y
        top_y = @graph_top + time_interval[0] * @graph_height
        bottom_y = @graph_top + time_interval[1] * @graph_height

        if top_y.between?(@graph_top, @graph_bottom) ||
          bottom_y.between?(@graph_top, @graph_bottom) ||
          (top_y <= @graph_top && bottom_y >= @graph_bottom)

          top_y = @graph_top if top_y <= @graph_top
          bottom_y = @graph_bottom if bottom_y >= @graph_bottom

          @d = @d.rectangle(left_x, top_y, right_x, bottom_y)
        end
      end
    end

    @d.draw(@base_image)

  end

  def draw_line_markers
    super

    (0..@marker_count).each do |index|
        y = @graph_top + @graph_height - index.to_f * @increment_scaled

        @d.fill = @font_color
        @d.font = @font if @font
        @d.stroke('transparent')
        @d.pointsize = scale_fontsize(@marker_font_size)
        @d.gravity = EastGravity

        # Vertically center with 1.0 for the height
        @d = @d.annotate_scaled(@base_image,
          @graph_left - LABEL_MARGIN, 1.0,
          0.0, y,
          Time.at(@maximum_value - @y_axis_increment * index).strftime(@time_format), @scale)
    end
  end

end
