# TODO
# Help / quick reference
# Show captures

require 'wx'
require 'strscan'
include Wx

REGEXP_OPTIONS = {
  "i" => Regexp::IGNORECASE,
  "x" => Regexp::EXTENDED,
  "m" => Regexp::MULTILINE
}

class RegexpOptionsValidator < Validator
  def initialize(*args)
    super
    evt_char :on_char
  end
  
  def on_char(e)
    valid_key_codes = [ K_BACK, K_DELETE, K_LEFT, K_RIGHT ] + (REGEXP_OPTIONS.keys - e.event_object.value.split("")).map { |k| k[0] }
    if valid_key_codes.include?( e.key_code )
      e.skip
    else
      bell        
    end
  end
end

class ReggieFrame < Frame
  
  def initialize(parent, options={})
    super
    # @panel = Panel.new(self) use panel for TAB_TRAVERSAL

    create_status_bar
    set_status_text "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]"
    
    large_mono_font = Font.new( 32, FONTFAMILY_TELETYPE, FONTSTYLE_NORMAL, FONTWEIGHT_NORMAL )
    small_mono_font = Font.new( 12, FONTFAMILY_TELETYPE, FONTSTYLE_NORMAL, FONTWEIGHT_NORMAL )
    
    @text_styles = {
      :non_match => TextAttr.new( BLACK, WHITE, small_mono_font ),
      :match => TextAttr.new( BLACK, LIGHT_GREY, small_mono_font ),
      :zero_width_match => TextAttr.new( WHITE, BLACK, small_mono_font ),
      :no_matches => TextAttr.new( RED, WHITE, small_mono_font )      
    }
    
    @regex_ctrl_text = TextCtrl.new( self, :size => [600, 50], :style => TE_RICH )
    @regex_ctrl_text.set_default_style TextAttr.new( BLACK, WHITE, large_mono_font )
    evt_text @regex_ctrl_text, :on_regex_ctrl_text_changed
    
    @regex_options_ctrl_text = TextCtrl.new( self, :size => [100, 50], :style => TE_RICH, :validator => RegexpOptionsValidator.new )
    @regex_options_ctrl_text.set_default_style TextAttr.new( BLACK, WHITE, large_mono_font )
    evt_text @regex_options_ctrl_text, :on_regex_options_ctrl_text_changed
    
    @test_string_ctrl_text = TextCtrl.new( self, :size => [280, 200], :style => TE_MULTILINE | TE_RICH )
    @test_string_ctrl_text.set_default_style TextAttr.new( BLACK, WHITE, small_mono_font )
    evt_text @test_string_ctrl_text, :on_test_string_ctrl_text_changed
    
    @results_ctrl = TextCtrl.new( self, :size => [280, 200], :style => TE_MULTILINE | TE_READONLY | TE_RICH )
    
    box = BoxSizer.new(VERTICAL)
    regex_box = FlexGridSizer.new(2, 2, 0, 10)
    regex_box.add( StaticText.new( self, :label => "Regular Expression" ), 0, EXPAND )
    regex_box.add( StaticText.new( self, :label => "Options" ), 0, EXPAND )
    regex_box.add( @regex_ctrl_text, 1, EXPAND )
    regex_box.add( @regex_options_ctrl_text, 0, EXPAND | ALIGN_RIGHT )
    regex_box.add_growable_col( 0 )
    box.add( regex_box, 0, EXPAND | ALL, 10 )
    
    box2 = FlexGridSizer.new(2, 2, 0, 10)
    box2.add( StaticText.new( self, :label => "Test String" ), 0, EXPAND )
    box2.add( StaticText.new( self, :label => "Results" ), 0, EXPAND )
    box2.add( @test_string_ctrl_text, 1, EXPAND )
    box2.add( @results_ctrl, 1, EXPAND )
    box2.add_growable_col( 0, 1 )
    box2.add_growable_col( 1, 1 )
    box2.add_growable_row( 1, 1 )
    box.add( box2, 1, EXPAND | ALL, 10 )
    set_sizer_and_fit( box )
    
    run_regex
  end
  
  def on_regex_ctrl_text_changed(e)
    run_regex
  end
  
  def on_test_string_ctrl_text_changed(e)
    run_regex
  end
  
  def on_regex_options_ctrl_text_changed(e)
    run_regex
  end
  
  def run_regex
    @results_ctrl.clear
    
    if @regex_ctrl_text.value == ""
      @results_ctrl.set_default_style @text_styles[:no_matches]
      @results_ctrl.append_text( "Please enter a regular expression..." )
      return
    end
    
    regex_options = REGEXP_OPTIONS.inject(0) do |acc, e|
      if @regex_options_ctrl_text.value.include?(e.first)
        acc | e.last
      else
        acc
      end
    end
    
    regex = Regexp.new( @regex_ctrl_text.value, regex_options ) rescue nil
    unless regex
      @results_ctrl.set_default_style @text_styles[:no_matches]
      @results_ctrl.append_text "Invalid regex"    
      return
    end
    
    # Use non-printing characters in the delimiters to ensure that no test strings will match
    begin_match_delimiter = "\bBEGIN DELIMITER\b"
    end_match_delimiter = "\bEND DELIMITER\b"
    
    results = @test_string_ctrl_text.value.gsub( regex ) do |s|
      "#{begin_match_delimiter}#{s}#{end_match_delimiter}"
    end
  
    num_matches = 0
    s = StringScanner.new( results )
    while r = s.scan_until( /#{begin_match_delimiter}.*?#{end_match_delimiter}/m )
      num_matches += 1
      @results_ctrl.set_default_style @text_styles[:non_match]
      @results_ctrl.append_text( r[0..-s.matched_size-1] )
      
      match = s.matched.sub(begin_match_delimiter, "").sub(end_match_delimiter, "")
      if match.size > 0
        @results_ctrl.set_default_style @text_styles[:match]
        @results_ctrl.append_text( match )
      else
        @results_ctrl.set_default_style @text_styles[:zero_width_match]
        @results_ctrl.append_text( " " )
      end
    end
    
    if num_matches > 0      
      @results_ctrl.set_default_style @text_styles[:non_match]
      @results_ctrl.append_text( s.rest )
    else
      @results_ctrl.set_default_style @text_styles[:no_matches]
      @results_ctrl.append_text( "No matches" )
    end
  end
end


class ReggieApp < App
  def on_init
    f = ReggieFrame.new(nil, :title => 'Reggie' )
    f.show
  end
end

app = ReggieApp.new
app.main_loop