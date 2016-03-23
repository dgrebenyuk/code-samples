# Add elasticsearch aggregation support to Tire https://github.com/karmi/retire
module Tire

  module Results

    class Collection
      attr_reader :aggregations

      def initialize(response, options={})
        @response    = response
        @options     = options
        @time        = response['took'].to_i
        @total       = response['hits']['total'].to_i rescue nil
        @facets      = response['facets']
        @suggestions = Suggestions.new(response['suggest']) if response['suggest']
        @max_score   = response['hits']['max_score'].to_f rescue nil
        @wrapper     = options[:wrapper] || Configuration.wrapper

        @aggregations = response['aggregations']
        @response["hits"]["hits"] = @aggregations["dedup"]["buckets"].map{|bucket| bucket["dedup_docs"]["hits"]["hits"] }.flatten if @aggregations
      end
    end
  end

  module Search

    class Search

      attr_reader :aggregations

      def aggregations(name, options={}, &block)
        @aggregations ||= {}
        @aggregations.update Aggregations.new(name, options, &block).to_hash
        self
      end

      def to_hash
        @options[:payload] || begin
          request = {}
          request.update( { :indices_boost => @indices_boost } ) if @indices_boost
          request.update( { :query  => @query.to_hash } )    if @query
          request.update( { :sort   => @sort.to_ary   } )    if @sort
          request.update( { :facets => @facets.to_hash } )   if @facets
          request.update( { :filter => @filters.first.to_hash } ) if @filters && @filters.size == 1
          request.update( { :filter => { :and => @filters.map {|filter| filter.to_hash} } } ) if  @filters && @filters.size > 1
          request.update( { :highlight => @highlight.to_hash } ) if @highlight
          request.update( { :suggest => @suggest.to_hash } ) if @suggest
          request.update( { :size => @size } )               if @size
          request.update( { :from => @from } )               if @from
          request.update( { :fields => @fields } )           if @fields
          request.update( { :partial_fields => @partial_fields } ) if @partial_fields
          request.update( { :script_fields => @script_fields } ) if @script_fields
          request.update( { :version => @version } )         if @version
          request.update( { :explain => @explain } )         if @explain
          request.update( { :min_score => @min_score } )     if @min_score
          request.update( { :track_scores => @track_scores } ) if @track_scores
          request.update( { :aggregations => @aggregations } ) if @aggregations
          request
        end
      end
    end

    class Aggregations
      attr_accessor :aggregations

      def initialize(name, options={}, &block)
        @name    = name
        @options = options
        @value   = {}
        block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
      end

      def aggregations(name, options={}, &block)
        @value[:aggregations] = Aggregations.new(name, options, &block).to_hash
        self
      end

      def terms(field, options={})
        size      = options.delete(:size) || 10
        all_terms = options.delete(:all_terms) || false
        @value[:terms] = if field.is_a?(Enumerable) and not field.is_a?(String)
          { :fields => field }.update({ :size => size}).update(options)
        else
          { :field => field  }.update({ :size => size}).update(options)
        end
        self
      end

      def top_hits(options={})
        size = options.delete(:size) || 10
        @value[:top_hits] = {:size => size}.update(options)
        self
      end

      def to_json(options={})
        to_hash.to_json
      end

      def to_hash
        @value.update @options
        { @name => @value }
      end
    end

  end
end
