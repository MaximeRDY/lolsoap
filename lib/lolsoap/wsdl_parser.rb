require 'nokogiri'

module LolSoap
  # @private
  class WSDLParser
    class Type
      attr_reader :parser, :node, :target_namespace, :name, :prefix

      def initialize(parser, node, target_namespace)
        @parser           = parser
        @node             = node
        @target_namespace = target_namespace
        @prefix, @name    = parse_prefix(node.attr('name'))
      end

      def name_with_prefix
        "#{prefix}:#{name}"
      end

      def elements
        Hash[
          node.xpath('.//xs:element', parser.ns).map do |element|
            prefix, name = parse_prefix(element.attr('name'))
            max_occurs   = element.attribute('maxOccurs').to_s

            [
              name,
              {
                :type     => parse_prefix(element.attr('type')).join(':'),
                :singular => max_occurs.empty? || max_occurs == '1'
              }
            ]
          end
        ]
      end

      private

      def parse_prefix(string)
        prefix, name = string.to_s.split(':')

        unless name
          name   = prefix
          prefix = parser.prefixes.fetch(target_namespace)
        end

        [prefix, name]
      end
    end

    NS = {
      :wsdl      => 'http://schemas.xmlsoap.org/wsdl/',
      :soap      => 'http://schemas.xmlsoap.org/wsdl/soap/',
      :soap12    => 'http://schemas.xmlsoap.org/wsdl/soap12/',
      :xmlschema => 'http://www.w3.org/2001/XMLSchema'
    }

    attr_reader :doc

    def self.parse(raw)
      new(Nokogiri::XML::Document.parse(raw))
    end

    def initialize(doc)
      @doc = doc
    end

    def namespaces
      @namespaces ||= begin
        namespaces = Hash[doc.collect_namespaces.map { |k, v| [k.sub(/^xmlns:/, ''), v] }]
        namespaces.delete('xmlns')
        namespaces
      end
    end

    def prefixes
      @prefixes ||= namespaces.invert
    end

    def endpoint
      @endpoint ||= doc.at_xpath('/d:definitions/d:service/d:port/s:address/@location', ns).to_s
    end

    def schemas
      doc.xpath('/d:definitions/d:types/xs:schema', ns)
    end

    def types
      @types ||= begin
        types = {}
        schemas.each do |schema|
          target_namespace = schema.attr('targetNamespace').to_s

          schema.xpath('xs:element[@name] | xs:complexType[@name]', ns).each do |node|
            type = Type.new(self, node, target_namespace)

            types[type.name_with_prefix] = {
              :name     => type.name,
              :prefix   => type.prefix,
              :elements => type.elements
            }
          end
        end
        types
      end
    end

    def messages
      @messages ||= Hash[
        doc.xpath('/d:definitions/d:message', ns).map do |msg|
          [
            msg.attribute('name').to_s,
            msg.at_xpath('./d:part/@element', ns).to_s
          ]
        end
      ]
    end

    def port_type_operations
      @port_type_operations ||= Hash[
        doc.xpath('/d:definitions/d:portType/d:operation', ns).map do |op|
          input  = op.at_xpath('./d:input/@message',  ns).to_s.split(':').last
          output = op.at_xpath('./d:output/@message', ns).to_s.split(':').last
          name   = op.attribute('name').to_s

          [name, { :input => messages.fetch(input), :output => messages.fetch(output) }]
        end
      ]
    end

    def operations
      @operations ||= begin
        binding = doc.at_xpath('/d:definitions/d:service/d:port/s:address/../@binding', ns).to_s.split(':').last

        Hash[
          doc.xpath("/d:definitions/d:binding[@name='#{binding}']/d:operation", ns).map do |op|
            name   = op.attribute('name').to_s
            action = op.at_xpath('./s:operation/@soapAction', ns).to_s

            [
              name,
              {
                :action => action,
                :input  => port_type_operations.fetch(name)[:input],
                :output => port_type_operations.fetch(name)[:output]
              }
            ]
          end
        ]
      end
    end

    def ns
      @ns ||= {
        'd'  => NS[:wsdl],
        'xs' => NS[:xmlschema],
        's'  => namespaces.values.include?(NS[:soap12]) ? NS[:soap12] : NS[:soap]
      }
    end
  end
end
