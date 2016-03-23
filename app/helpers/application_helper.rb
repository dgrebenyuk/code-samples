require "nokogiri"

module ApplicationHelper
 
  def icon_tag(icon_name, options = {})
    classes = ["icon fa fa-#{icon_name}", options.delete(:class)].compact
    content_tag(:i, "", options.merge(class: classes.join(' ')))
  end

  def display_address(address = "")
    if address && address.count(',') >= 2
      parts        = address.split(',')
      city_zip     = parts.pop(2).join(",")
      address_line = parts.join("<br />")

      "#{address_line}<br />#{city_zip}".html_safe
    else
      address
    end
  end

  # override or nullify the page title
  def title(title=nil, prefix='E2G2')
    prefix ||= 'E2G2'
    @title = "#{prefix} - #{title}".html_safe
  end

  # override or nullify the page header
  def page_header(page_header=nil)
    if page_header
      @page_header = "<h1 id=\"page_header\">#{page_header}</h1>".html_safe
    else
      @page_header = ''.html_safe
    end
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    order     = params[:sort] ? params[:sort] : "created_at"
    order_dir = params[:direction] ? params[:direction] : "desc"

    css_class = column == order ? "current #{order_dir}" : nil
    direction = column == order && order_dir == "asc" ? "desc" : "asc"

    options = params.dup
    [:controller, :action, :menu_context].each {|param| options.delete(param) }
    link_to title, options.merge!({:sort => column, :direction => direction}), {:class => css_class}
  end

  class E2G2FormBuilder < ActionView::Helpers::FormBuilder
    def html_area(method, options = {})
      editor_id = "#{object_name}_#{method}"
      editor_config = "
        var instance = CKEDITOR.instances.#{editor_id};
        if(instance) {
          CKEDITOR.remove(instance)
        }

        CKEDITOR.config.autoParagraph = false;
        CKEDITOR.config.enterMode = CKEDITOR.ENTER_BR;

        #{ "CKEDITOR.config.forcePasteAsPlainText = true;" if options.delete(:forcePasteAsPlainText) }

        CKEDITOR.replace('#{editor_id}', {
          toolbar : [
            ['Format','-','Bold','Italic','-','NumberedList','BulletedList','-','Outdent','Indent']
          ],
          resize_enabled: false,
          on: {
            blur: function(e) {
              e.editor.updateElement();
            }
          }
        });
      "
      options.merge!(:object => object)
      @template.content_tag :div, @template.text_area(object_name, method, options) + @template.raw(@template.javascript_tag(editor_config)), :class => 'html_area_container'
    end

    # TODO: abstract this out to do code in multiple languages ex: f.code_editor :field, mode: :lua
    def code_editor(method, options = {})
      ace_mode    = options.delete(:mode) || "markdown"
      ace_theme   = options.delete(:theme) || "textmate"
      ace_name    = "ace_#{SecureRandom.uuid.underscore}"

      ace_config  = <<-JS
        var #{ace_name}           = ace.edit('#{ace_name}_editor'),
            #{ace_name}_textarea  = document.getElementById('#{ace_name}_textarea'),
            #{ace_name}_preview   = document.getElementById('#{ace_name}_preview');

        #{ace_name}.setTheme('ace/theme/#{ace_theme}');
        #{ace_name}.setDisplayIndentGuides(true);
        #{ace_name}.setOptions({
          displayIndentGuides: true,
          enableBasicAutocompletion: true,
          fontSize: 13,
          highlightActiveLine: true,
          highlightGutterLine: true,
          highlightSelectedWord: true,
          showFoldWidgets: false
        });
        #{ace_name}.session.setMode('ace/mode/#{ace_mode}');
        #{ace_name}.session.setValue("#{@template.j(object.send(method))}");
        #{ace_name}.session.on('change', function() {
          if(!#{ace_name}.completer) #{ace_name}.completer = new Autocomplete();
          #{ace_name}.completer.showPopup(#{ace_name});
          #{ace_name}.completer.cancelContextMenu();
          var editor_value = #{ace_name}.session.getValue();
          #{ace_name}_textarea.value = editor_value;
          #{ace_name}_preview.contentDocument.getElementById('markdown_preview').innerHTML = markdown.makeHtml(editor_value);
        });

        #{ace_name}_preview.onload = function() {
          #{ace_name}_preview.contentDocument.getElementById('markdown_preview').innerHTML = markdown.makeHtml(#{ace_name}.session.getValue());
        };
      JS

      config          = @template.raw(@template.javascript_tag(ace_config))
      textarea        = @template.text_area(object_name, method, options.merge(id: "#{ace_name}_textarea", style: 'display:none;'))
      editor          = @template.content_tag(:div, '', class: 'editor', id: "#{ace_name}_editor")
      preview         = @template.content_tag(:iframe, '', src: '/preview/markdown', class: 'preview', id: "#{ace_name}_preview")

      @template.content_tag(:div, [textarea, preview, editor, config].join.html_safe, class: 'code_editor')
    end
  end
  ActionView::Base.default_form_builder = E2G2FormBuilder

  # used to place validation errors where they are not necessarily assigned to a specific field
  def errors_for(object, attribute)
    if errors = object.errors[attribute]
    errors = [errors] unless errors.is_a?(Array)
      return '<ul class="custom_errors">' + errors.map {|e| "<li> &rsaquo; " + e + "</li>"}.join + "</ul>".html_safe
    end
  end

  def messages
    error   = flash[:error] || flash[:alert]
    notice  = flash[:notice] || flash[:info]
    errors = content_tag(:div, :class => "alert alert-danger alert-dismissable") { content_tag(:button, '&times;'.html_safe, :class => 'close', :'data-dismiss' => 'alert', :type => 'button') + error.html_safe } unless error.blank?
    notices = content_tag(:div, :class => "alert alert-success alert-dismissable") { content_tag(:button, '&times;'.html_safe, :class => 'close', :'data-dismiss' => 'alert', :type => 'button') + notice.html_safe }unless notice.blank?

    "#{errors}#{notices}".html_safe
  end

  def markdown_to_html(content)
    GitHub::Markdown.render(content.to_s).html_safe
  end

  ##################################
  # V2 Foundation / Backbone Helpers
  #
  def jbuilder_string(template, locals = {})
    render(partial: template, locals: locals, formats: [:json]).html_safe
  end

  def jbuilder_backbone(template, locals = {})
    original_formats  = formats
    self.formats      = [:json]

    json = JbuilderTemplate.new(self)
    json.partial!(template, locals)
    json.target!.html_safe
  ensure
    self.formats = original_formats
  end

  def jbuilder(template, locals = {})
    original_formats  = self.formats
    self.formats      = [:json]
    ::MultiJson.decode(render(partial: template, locals: locals, formats: [:json], handlers: [:jbuilder]))
  ensure
    self.formats = original_formats
  end

  def xml_pretty(xml_text)
    xsl = <<-XSL
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
      <xsl:strip-space elements="*"/>
      <xsl:template match="/">
        <xsl:copy-of select="."/>
      </xsl:template>
    </xsl:stylesheet>
    XSL

    xslt = Nokogiri::XSLT(xsl)
    xslt.transform(Nokogiri::XML(xml_text.to_s)).to_xml
  end

  def cut_url(url, owner=nil)
    short_url = Shortener::ShortenedUrl.generate(url, owner)

    if short_url
      url_for controller: :"/shortener/shortened_urls",
              action: :show,
              id: short_url.unique_key,
              subdomain: nil,
              locale: false,
              only_path: false
    else
      url
    end
  end
end
