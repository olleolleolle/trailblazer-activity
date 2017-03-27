require "test_helper"

class AlterTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  class A
  end
  class C
  end
  class B
  end

  let (:ends) { {end: { right: Circuit::End.new(:right), left: Circuit::End.new(:left) }} }

  describe "before" do
    let(:activity) do
      Circuit::Activity({id: "A/"}, ends) { |evt|
        {
          evt[:Start] => { Circuit::Right => evt[:End, :right], Circuit::Left => evt[:End, :left] },
        }
      }
    end

    # Start -> End
    #       -> End
    it { activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>#<End: left {}>}}" }

    it do
      # Start -> A -> End
      #       ->      End
      _activity = Circuit::Activity::Alter(activity, :before, activity[:End, :right], A, direction: Circuit::Right )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>A, Left=>#<End: left {}>}, A=>{Right=>#<End: right {}>}}"

      # Start -> A -> B -> End
      _activity = Circuit::Activity::Alter(_activity, :before, activity[:End, :right], B, direction: Circuit::Right )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>A, Left=>#<End: left {}>}, A=>{Right=>B}, B=>{Right=>#<End: right {}>}}"
    end

    # on LEFT track.
    it do
      # Start ->      End
      #       -> A -> End
      _activity = Circuit::Activity::Alter(activity, :before, activity[:End, :left], A, direction: Circuit::Left )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>A}, A=>{Left=>#<End: left {}>}}"

      _activity = Circuit::Activity::Alter(_activity, :before, activity[:End, :left], B, direction: Circuit::Left )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>A}, A=>{Left=>B}, B=>{Left=>#<End: left {}>}}"
    end

    describe "multiple lines pointing to A" do
      let(:activity) do
        Circuit::Activity({id: "A/"}, ends) { |evt|
          {
            evt[:Start] => { Circuit::Right => A, Circuit::Left => C },
            C => { Circuit::Right => A, Circuit::Left => evt[:End, :left] },
            A => { Circuit::Right => evt[:End, :right] },
          }
        }
      end

      # push B before A (which has two inputs).
      it do
        # Start ->   B -> A -> End
        #       -> C ^ ->      End
        _activity = Circuit::Activity::Alter(activity, :before, A, B, direction: Circuit::Right )
        _activity.must_inspect "{#<Start: default {}>=>{Right=>B, Left=>C}, C=>{Right=>B, Left=>#<End: left {}>}, A=>{Right=>#<End: right {}>}, B=>{Right=>A}}"
      end
    end
  end



  # append ===============
  let(:activity) do
    Circuit::Activity(id: "A/") { |evt|
      {
        evt[:Start] => { Circuit::Right => A },
        A           => { Circuit::Right => B },
        B           => { Circuit::Right => evt[:End] }
      }
    }
  end

  it { activity.must_inspect "{#<Start: default {}>=>{Right=>A}, A=>{Right=>B}, B=>{Right=>#<End: default {}>}}" }
  it { Circuit::Activity::Alter(activity, :append, C).must_inspect "{#<Start: default {}>=>{Right=>A}, A=>{Right=>B}, B=>{Right=>C}, C=>{Right=>#<End: default {}>}}" }
end

module MiniTest::Assertions
  def assert_inspect(text, subject)
    circuit, _ = subject.values
    map, _ = circuit.to_fields
    map.inspect.gsub(/0x.+?lambda\)/, "").gsub("Trailblazer::Circuit::", "").gsub("AlterTest::", "").must_equal(text)
  end
end
Trailblazer::Circuit::Activity.infect_an_assertion :assert_inspect, :must_inspect
