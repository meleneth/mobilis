# frozen_string_literal: true

RSpec.describe Mobilis::PrettyPrint::PrettyPrintable do
  let(:child_class) do
    Class.new do
      include Mobilis::PrettyPrint::PrettyPrintable

      def ppx_fields(dsl)
        dsl.instance_value "child-value", "beta"
      end
    end
  end

  let(:parent_class) do
    child = child_class

    Class.new do
      include Mobilis::PrettyPrint::PrettyPrintable

      define_method(:child) { child.new }

      def ppx_fields(dsl)
        dsl.instance_value "root-value", "alpha"
        dsl.child_object "child", child
      end
    end
  end

  it "renders object fields and direct children" do
    rendered = parent_class.new.pp

    expect(rendered).to include("root-value: alpha")
    expect(rendered).to include("child-value: beta")
  end
end
