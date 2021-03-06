require 'test/common'

describe "Union types" do
  before do
    @registry = Registry.new
    [:boolean, :null, :complex, :real, :rational, :integer, :any, :nothing].each do |t|
      instance_variable_set("@#{t}", @registry[t])
    end
  end

  describe "Nothing" do

    it "is the overall bottom type: a subtype of anything one cares to shake a stick at" do
      [
        @any,
        @boolean,
        @null,
        @complex,
        @real,
        @rational,
        @integer,
        Type::Sequence.new(@boolean),
        Type::Tuple.new(@boolean, @real),
        Type::Object.new('Object', :foo => @boolean)
      ].each do |t|
        assert_operator @nothing, :<, t
      end

      assert_operator @nothing, :<=, @nothing
      refute_operator @any, :<= ,@nothing
    end

  end

  describe "Any" do
    it "is the overall top type: a supertype of anything one cares to shake a stick at" do
      [
        @boolean,
        @null,
        @complex,
        @real,
        @rational,
        @integer,
        Type::Sequence.new(@boolean),
        Type::Sequence.new(@any),
        Type::Tuple.new(@boolean, @real, @any),
        Type::Object.new('Object', :foo => @boolean),
        @nothing
      ].each do |t|
        assert_operator t, :<, @any
      end

      assert_operator @any, :<=, @any
      refute_operator @nothing, :>= ,@any
    end
  end

  describe "union" do
    it "should not be sensitive to ordering when doing comparisons" do
      assert_equal \
        Type::Union.new(@boolean, @integer),
        Type::Union.new(@integer, @boolean)
    end

    it "should have an empty union equal to NOTHING" do
      assert_equal @nothing, Type::Union.new()
    end

    it "should have a single-clause Union equal to the single item on its own" do
      assert_equal @boolean, Type::Union.new(@boolean)
    end

    it "should have a nested union equal to the flattened-out version" do
      union = Type::Union.new(@boolean, @integer)
      union = Type::Union.new(union, @null)
      assert_equal union, Type::Union.new(@boolean, @integer, @null)
    end

    it "should have the things in the union be subtypes of it (and things not, not)" do
      union = Type::Union.new(@boolean, @integer)
      assert @boolean < union
      assert @integer < union
      assert_false @null < union
    end

    it "should equate the upper bound with the union in cases where it contains an upper bound" do
      assert_equal @real, Type::Union.new(@real, @integer)
      assert_equal @complex, Type::Union.new(@rational, @complex)
    end

    it "should have the union of sequences be a subtype of a sequence of unions" do
      union_seq = Type::Union.new(Type::Sequence.new(@boolean), Type::Sequence.new(@null))
      seq_union = Type::Sequence.new(Type::Union.new(@boolean, @null))
      assert_operator union_seq, :<, seq_union
    end

    it "should not mind a duplicate" do
      assert_equal @complex, Type::Union.new(@complex, @complex)

      assert_equal Type::Union.new(@complex, @null), Type::Union.new(@complex, @complex, @null)

      # uses type equality
      assert_equal Type::Sequence.new(@boolean), Type::Union.new(Type::Sequence.new(@boolean), Type::Sequence.new(@boolean))
    end

    it "should have a union of tuples be a subtype of a tuple of unions" do
      union_tup = Type::Union.new(Type::Tuple.new(@boolean, @integer), Type::Tuple.new(@null, @real))
      tup_union = Type::Tuple.new(Type::Union.new(@boolean, @null), @real)
      assert_operator union_tup, :<, tup_union
    end

    it "should type-check basic unions" do
      assert Type::Union.new(@integer, @null) === nil
      assert Type::Union.new(@integer, @null) === 123
      refute Type::Union.new(@integer, @null) === false
    end

    describe "unions of object types" do
      it "should allow a union to be a subtype of something only when all of its clauses are a subtype of it" do
        union = Type::Union.new(
          Type::Object.new('TestClass', :foo => @integer),
          Type::Object.new('TestClass2', :bar => @integer)
        )
        assert_operator union, :<=, Type::Object.new('Object')

        refute_operator union, :<=, Type::Object.new('Object', :foo => @integer)
        refute_operator union, :<=, Type::Object.new('Object', :bar => @integer)
        refute_operator union, :<=, Type::Object.new('Object', :xyz => @integer)
      end

      # untagged unions however are currently not allowed and if allowed might be simplified
      it "should not simplify tagged unions to be equal to a crude upper bound" do
        union = Type::Union.new(
          Type::Object.new('TestClass', :foo => @integer),
          Type::Object.new('TestClass2', :bar => @integer)
        )
        # the union is a strict subtype of this, not equal:
        assert_operator Type::Object.new('Object'), :>, union
      end

      it "should, when type tags have a common upper bound amongst them, have the union equal the upper bound" do
        union = Type::Union.new(
          Type::Object.new('TestSubclass'),
          Type::Object.new('TestClass')
        )
        assert_equal Type::Object.new('TestClass'), union

        union = Type::Union.new(
          Type::Object.new('TestClass'),
          Type::Object.new('TestSubclass')
        )
        assert_equal Type::Object.new('TestClass'), union

        union = Type::Union.new(
          Type::Object.new('TestClass2'),
          Type::Object.new('TestSubclass'),
          Type::Object.new('TestModule')
        )
        assert_equal Type::Object.new('TestModule'), union
      end

      it "should, when there are non-overlapping groups some of which can be unified, have the union equal to the union of the unified upper bounds" do
        union = Type::Union.new(
          # one group
          Type::Object.new('TestClass2'),
          # another
          Type::Object.new('TestClass'),
          Type::Object.new('TestSubclass')
        )
        assert_equal Type::Union.new(
          Type::Object.new('TestClass2'),
          Type::Object.new('TestClass')
        ), union
      end

      AbcDef = Class.new(OpenStruct)
      GhiJkl = Class.new(OpenStruct)

      it "should type-check against the clause of the union whose tag the instance matches" do
        union = Type::Union.new(
          (first_clause = Type::Object.new('AbcDef', :abc => @integer)),
          Type::Object.new('GhiJkl', :def => @integer)
        )

        assert_operator union, :===, AbcDef.new(:abc => 123)
        assert_operator union, :===, GhiJkl.new(:def => 123)

        refute_operator union, :===, AbcDef.new
        refute_operator union, :===, GhiJkl.new
      end
    end


  end
end
