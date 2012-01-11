require 'helper'
require 'lolsoap/envelope'

module LolSoap
  describe Envelope do
    let(:wsdl) { OpenStruct.new(:namespaces => { 'foo' => 'http://example.com/foo' }) }
    let(:operation) do
      OpenStruct.new(:input_prefix => 'foo', :input_name => 'WashHandsRequest', :input => Object.new)
    end

    subject { Envelope.new(wsdl, operation) }

    let(:doc) { subject.doc }
    let(:header) { doc.at_xpath('/soap:Envelope/soap:Header', doc.namespaces) }
    let(:input) { doc.at_xpath('/soap:Envelope/soap:Body/foo:WashHandsRequest', doc.namespaces) }

    it 'has a skeleton SOAP envelope structure when first created' do
      doc.namespaces.must_equal(
        'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:foo'  => 'http://example.com/foo'
      )

      header.wont_equal nil
      header.children.length.must_equal 0

      input.wont_equal nil
      input.children.length.must_equal 0
    end

    describe '#body' do
      it 'yields and returns a builder object for the body' do
        builder = Object.new

        builder_klass = MiniTest::Mock.new
        builder_klass.expect(:new, builder, [input, operation.input])

        block = nil
        ret = subject.body(builder_klass) { |b| block = b }

        ret.must_equal builder
        block.must_equal builder
      end

      it "doesn't require a block" do
        builder = Object.new

        builder_klass = MiniTest::Mock.new
        builder_klass.expect(:new, builder, [input, operation.input])

        subject.body(builder_klass).must_equal builder
      end
    end

    describe '#header' do
      it 'yields and returns the xml builder object for the header' do
        builder = Object.new

        builder_klass = MiniTest::Mock.new
        builder_klass.expect(:new, builder, [header])

        block = nil
        ret = subject.header(builder_klass) { |b| block = b }

        ret.must_equal builder
        block.must_equal builder
      end

      it "doesn't require a block" do
        builder = Object.new

        builder_klass = MiniTest::Mock.new
        builder_klass.expect(:new, builder, [header])

        subject.header(builder_klass).must_equal builder
      end
    end

    describe '#endpoint' do
      it 'delegates to wsdl' do
        wsdl.endpoint = 'lol'
        subject.endpoint.must_equal 'lol'
      end
    end

    describe '#to_xml' do
      it 'returns the xml of the doc' do
        def subject.doc; OpenStruct.new(:to_xml => '<lol>'); end
        subject.to_xml.must_equal '<lol>'
      end
    end

    describe '#action' do
      it "returns the operation's action" do
        operation.action = 'lol'
        subject.action.must_equal 'lol'
      end
    end
  end
end