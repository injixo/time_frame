
# frozen_string_literal: true

require 'spec_helper'

describe TimeFrame do
  let(:time) { Time.zone.local(2012) }
  let(:duration) { 2.hours }

  before do
    # Avoid i18n deprecation warning
    I18n.enforce_available_locales = true
  end

  it 'is hashable' do
    hash = {}
    time_frame1 = TimeFrame.new(min: time, duration: duration)
    time_frame2 = TimeFrame.new(min: time, duration: duration)
    time_frame3 = TimeFrame.new(min: time, duration: duration / 2)
    time_frame4 = TimeFrame.new(min: time - duration / 2, max: time + duration)
    hash[time_frame1] = 1
    expect(hash[time_frame2]).to eq 1
    expect(hash[time_frame3]).not_to eq 1
    expect(hash[time_frame4]).not_to eq 1
  end

  describe '#min and #max' do
    context 'when given two times' do
      context 'and min is smaller than max' do
        subject { TimeFrame.new(min: time, max: time + duration) }

        describe '#min' do
          subject { super().min }
          it { should eq time }
        end

        describe '#max' do
          subject { super().max }
          it { should eq time + duration }
        end
      end
      context 'and max is smaller than min' do
        specify do
          expect do
            TimeFrame.new(min: time, max: time - 1.day)
          end.to raise_error(ArgumentError)
        end
      end
      context 'which are equal' do
        subject { TimeFrame.new(min: time, max: time) }

        describe '#min' do
          subject { super().min }
          it { should eq time }
        end

        describe '#max' do
          subject { super().max }
          it { should eq time }
        end
      end
    end

    context 'when time and duration is given' do
      context ' and duration is positive' do
        subject { TimeFrame.new(min: time, duration: 1.hour) }

        describe '#min' do
          subject { super().min }
          it { should eq time }
        end

        describe '#max' do
          subject { super().max }
          it { should eq time + 1.hour }
        end
      end
      context 'and duration is negative' do
        let(:invalid_t_r) { TimeFrame.new(min: time, duration: - 1.hour) }
        specify { expect { invalid_t_r }.to raise_error(ArgumentError) }
      end
      context 'and duration is 0' do
        subject { TimeFrame.new(min: time, duration: 0.hour) }

        describe '#min' do
          subject { super().min }
          it { should eq time }
        end

        describe '#max' do
          subject { super().max }
          it { should eq time }
        end

        context 'when min is a date' do
          context 'and duration is 0' do
            it 'is valid' do
              expect do
                TimeFrame.new(min: Time.utc(2012), duration: 0.seconds)
              end.not_to raise_error
            end
          end
        end
      end
      context 'and time sframe covers a DST shift' do
        let(:time) do
          Time.use_zone('Europe/Berlin') { Time.zone.local(2013, 10, 27) }
        end
        subject { TimeFrame.new(min: time, duration: 1.day) }

        describe '#min' do
          subject { super().min }
          it { should eq time }
        end

        describe '#max' do
          subject { super().max }
          it { should eq time + 25.hours }
        end
      end
    end

    specify '#min and #max are nil if time frame is empty' do
      expect(TimeFrame::EMPTY.min).to be_nil
      expect(TimeFrame::EMPTY.max).to be_nil
    end
  end

  describe '#duration' do
    context 'when borders are different' do
      subject { TimeFrame.new(min: time, duration: 2.hours).duration }
      it { should eq 2.hours }
    end
    context 'when borders are equal' do
      subject { TimeFrame.new(min: time, max: time).duration }
      it { should eq 0 }
    end
    context 'when time frame containts a DST shift' do
      it 'gains 1 hour on summer -> winter shifts' do
        Time.use_zone('Europe/Berlin') do
          time_frame = TimeFrame.new(min: Time.zone.local(2013, 10, 27),
                                     max: Time.zone.local(2013, 10, 28))
          expect(time_frame.duration).to eq 25.hours
        end
      end
      it 'loses 1 hour on winter -> summer shifts' do
        Time.use_zone('Europe/Berlin') do
          time_frame = TimeFrame.new(min: Time.zone.local(2013, 3, 31),
                                     max: Time.zone.local(2013, 4, 1))
          expect(time_frame.duration).to eq 23.hours
        end
      end
    end
    it 'returns 0 when time frame is empty' do
      expect(TimeFrame::EMPTY.duration).to eq 0
    end
  end

  describe '#==' do
    let(:time_frame) { TimeFrame.new(min: time, duration: 2.hours) }
    context 'when borders are equal' do
      let(:other) { TimeFrame.new(min: time, duration: 2.hours) }
      subject { time_frame == other }
      it { should be true }
    end
    context 'when min value is different' do
      let(:other) do
        TimeFrame.new(min: time - 1.hour, max: time + 2.hours)
      end
      subject { time_frame == other }
      it { should be false }
    end
    context 'when max value is different' do
      let(:other) { TimeFrame.new(min: time, duration: 3.hours) }
      subject { time_frame == other }
      it { should be false }
    end
    it 'returns true when self and the argument are both empty' do
      expect(TimeFrame::EMPTY).to eq TimeFrame::EMPTY
    end
    it 'returns false if argument is empty, but self is not' do
      expect(
        TimeFrame.new(min: time, duration: 3.hours)
      ).not_to eq TimeFrame::EMPTY
    end
    it 'returns false if self is empty, but argument is not' do
      expect(
        TimeFrame::EMPTY
      ).not_to eq TimeFrame.new(min: time, duration: 3.hours)
    end
  end

  describe '#<=>' do
    let(:time_frames) do
      array = TimeFrame.new(min: Time.utc(2014), duration: 30.days)
                       .split_by_interval(1.day)
      time_frame1 = TimeFrame.new(min: Time.utc(2014), duration: 2.days)
      array << time_frame1
      array << time_frame1.shift_by(1.day)
      array << time_frame1.shift_by(2.day)
      array
    end
    it 'sorts correctly' do
      to_be_sorted = time_frames.shuffle
      to_be_sorted.sort!
      to_be_sorted.each_cons(2) do |time_frame1, time_frame2|
        expect(time_frame1.min <= time_frame2.min).to be_truthy
        expect(time_frame1.max <= time_frame2.max).to be_truthy
      end
    end
  end

  describe '#cover?' do
    let(:time_frame) { TimeFrame.new(min: time, duration: 4.hours) }
    context 'when argument is a Time instance' do
      context 'and its covered' do
        context 'and equal to min' do
          subject { time_frame.cover?(time_frame.min) }
          it { should be true }
        end
        context 'and equal to max' do
          subject { time_frame.cover?(time_frame.max) }
          it { should be true }
        end
        context 'and is an inner value' do
          subject { time_frame.cover?(time_frame.min + 1.hour) }
          it { should be true }
        end
      end
      context 'and its not covered' do
        context 'and smaller than min' do
          subject { time_frame.cover?(time_frame.min - 1.hour) }
          it { should be false }
        end
        context 'and greater than max' do
          subject { time_frame.cover?(time_frame.max + 5.hours) }
          it { should be false }
        end
      end
    end
    context 'when argument is a TimeFrame' do
      context 'and its covered' do
        context 'and they have the same min value' do
          let(:other) { TimeFrame.new(min: time_frame.min, duration: 2.hours) }
          subject { time_frame.cover?(other) }
          it { should be true }
        end
        context 'and they have the same max value' do
          let(:other) do
            TimeFrame.new(min: time_frame.min + 1.hour, max: time_frame.max)
          end
          subject { time_frame.cover?(other) }
          it { should be true }
        end
        context 'and it is within the interior of self' do
          let(:other) do
            TimeFrame.new(
              min: time_frame.min + 1.hour, max: time_frame.max - 1.hour
            )
          end
          subject { time_frame.cover?(other) }
          it { should be true }
        end
        context 'and are equal' do
          let(:other) { time_frame.clone }
          subject { time_frame.cover?(other) }
          it { should be true }
        end
      end
      context 'and it is not covered' do
        context 'and other is left of self' do
          let(:other) { time_frame.shift_by(-5.hours) }
          subject { time_frame.cover?(other) }
          it { should be false }
        end
        context 'and other overlaps left hand side' do
          let(:other) { time_frame.shift_by(-1.hour) }
          subject { time_frame.cover?(other) }
          it { should be false }
        end
        context 'and other overlaps left hand side at the border only' do
          let(:other) { time_frame.shift_by(-time_frame.duration) }
          subject { time_frame.cover?(other) }
          it { should be false }
        end
        context 'and other is right of self' do
          let(:other) { time_frame.shift_by(5.hours) }
          subject { time_frame.cover?(other) }
          it { should be false }
        end
        context 'and other overlaps right hand side' do
          let(:other) { time_frame.shift_by(1.hours) }
          subject { time_frame.cover?(other) }
          it { should be false }
        end
        context 'and other overlaps right hand side at the border only' do
          let(:other) { time_frame.shift_by(time_frame.duration) }
          subject { time_frame.cover?(other) }
          it { should be false }
        end
      end
    end
    it 'returns true when argument is empty' do
      expect(
        TimeFrame.new(min: time, duration: 3.hours)
      ).to cover(TimeFrame::EMPTY)
    end
    it 'returns true when self and argument are both empty' do
      expect(TimeFrame::EMPTY).to cover(TimeFrame::EMPTY)
    end
    it 'returns false when only self is empty' do
      expect(
        TimeFrame::EMPTY
      ).not_to cover(TimeFrame.new(min: time, duration: 3.hours))
    end
    it 'returns true when only the argument is empty' do
      expect(
        TimeFrame.new(min: time, duration: 3.hours)
      ).to cover(TimeFrame::EMPTY)
    end
  end

  describe '#time_between' do
    let(:time_frame) do
      TimeFrame.new(min: Time.zone.local(2012), duration: 2.days)
    end
    context 'when providing a time object' do
      describe 'when self covers time' do
        context 'and time equals min' do
          let(:time) { time_frame.min }
          subject { time_frame.time_between(time) }
          it { should eq 0.minutes }
        end
        context 'and time equals max' do
          let(:time) { time_frame.max }
          subject { time_frame.time_between(time) }
          it { should eq 0.minutes }
        end
        context 'and time is an interior point of self' do
          let(:time) { time_frame.min + (time_frame.duration / 2.0) }
          subject { time_frame.time_between(time) }
          it { should eq 0.minutes }
        end
      end
      context 'when self do not cover time' do
        context 'and time is smaller than the left bound' do
          let(:time) { time_frame.min - 42.hours - 42.minutes }
          subject { time_frame.time_between(time) }
          it { should eq(42.hours + 42.minutes) }
        end
        context 'and time is greater than the right bound' do
          let(:time) { time_frame.max + 42.hours + 42.minutes }
          subject { time_frame.time_between(time) }
          it { should eq 42.hours + 42.minutes }
        end
      end
    end
    context 'when providing a time_frame' do
      describe 'when self overlaps other' do
        context 'and its partly' do
          let(:other) { time_frame.shift_by(time_frame.duration / 2) }
          subject { time_frame.time_between(other) }
          it { should eq 0.minutes }
        end
        context 'and time equals max' do
          let(:other) { time_frame }
          subject { time_frame.time_between(other) }
          it { should eq 0.minutes }
        end
        context 'and other lies in the interior of self' do
          let(:other) do
            TimeFrame.new(min: time_frame.min + 1.hour, duration: 1.hour)
          end
          subject { time_frame.time_between(other) }
          it { should eq 0.minutes }
        end
      end
      context 'when self do not cover time' do
        context 'and time is smaller than the left bound' do
          let(:other) { time_frame.shift_by(-2.days - 42.seconds) }
          subject { time_frame.time_between(other) }
          it { should eq(42.seconds) }
        end
        context 'and time is greater than the right bound' do
          let(:other) { time_frame.shift_by(2.days + 42.seconds) }
          subject { time_frame.time_between(other) }
          it { should eq 42.seconds }
        end
      end
      it 'fails when only argument is empty' do
        expect(-> { time_frame.time_between(TimeFrame::EMPTY) })
          .to raise_error ArgumentError
      end
      it 'fails when only self is empty' do
        expect(-> { TimeFrame::EMPTY.time_between(time_frame) })
          .to raise_error TypeError
      end
    end
  end

  describe '#empty?' do
    it 'returns false when self is not contains at least one point' do
      expect(TimeFrame.new(min: time, max: time)).not_to be_empty
    end

    it 'returns true when self is empty' do
      expect(TimeFrame::EMPTY).to be_empty
    end
  end

  describe '.union' do
    context 'when given an empty array' do
      subject { TimeFrame.union([]) }
      it { should eq [] }
    end

    context 'when given a single time frame' do
      let(:time_frame) { TimeFrame.new(min: time, duration: 1.hour) }
      subject { TimeFrame.union([time_frame]) }
      it { should eq [time_frame] }
    end

    context 'when getting single element it returns a dup' do
      let(:time_frames) { [TimeFrame.new(min: time, duration: 1.hour)] }
      subject { TimeFrame.union(time_frames) }
      it { should_not equal time_frames }
    end

    context 'when given time frames' do
      context 'in order' do
        context 'and no sorted flag is provided' do
          context 'that are overlapping' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
            let(:time_frame2) { time_frame1.shift_by(1.hour) }
            let(:expected) do
              [TimeFrame.new(min: time_frame1.min, max: time_frame2.max)]
            end
            subject { TimeFrame.union([time_frame1, time_frame2]) }
            it { should eq expected }
          end
          context 'that are overlapping and first contains the second' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: 3.hours) }
            let(:time_frame2) do
              TimeFrame.new(min: time + 1.hour, duration: 1.hour)
            end
            let(:expected) { [time_frame1] }
            subject { TimeFrame.union([time_frame1, time_frame2]) }
            it { should eq expected }
          end
          context 'that are disjoint' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
            let(:time_frame2) { time_frame1.shift_by(3.hours) }
            subject { TimeFrame.union([time_frame1, time_frame2]) }
            it { should eq [time_frame1, time_frame2] }
          end
          context 'that intersect at their boundaries' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: + 2.hour) }
            let(:time_frame2) { time_frame1.shift_by(time_frame1.duration) }
            let(:expected) do
              [TimeFrame.new(min: time_frame1.min, max: time_frame2.max)]
            end
            subject { TimeFrame.union([time_frame1, time_frame2]) }
            it { should eq expected }
          end
        end
        context 'and the sorted flag is provided' do
          context 'that are overlapping' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
            let(:time_frame2) { time_frame1.shift_by(1.hour) }
            let(:expected) do
              [TimeFrame.new(min: time_frame1.min, max: time_frame2.max)]
            end
            subject do
              TimeFrame.union([time_frame1, time_frame2], sorted: true)
            end
            it { should eq expected }
          end
          context 'that are disjoint' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
            let(:time_frame2) { time_frame1.shift_by(3.hours) }
            subject do
              TimeFrame.union([time_frame1, time_frame2], sorted: true)
            end
            it { should eq [time_frame1, time_frame2] }
          end
          context 'that intersect at their boundaries' do
            let(:time_frame1) { TimeFrame.new(min: time, duration: + 2.hour) }
            let(:time_frame2) { time_frame1.shift_by(time_frame1.duration) }
            let(:expected) do
              [TimeFrame.new(min: time_frame1.min, max: time_frame2.max)]
            end
            subject do
              TimeFrame.union([time_frame1, time_frame2], sorted: true)
            end
            it { should eq expected }
          end
        end
      end
      context 'not in order' do
        context 'that are overlapping' do
          let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
          let(:time_frame2) { time_frame1.shift_by(1.hour) }
          subject { TimeFrame.union([time_frame2, time_frame1]) }
          it do
            should eq [
              TimeFrame.new(min: time_frame1.min, max: time_frame2.max)
            ]
          end
        end
        context 'that are disjoint' do
          let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
          let(:time_frame2) { time_frame1.shift_by(3.hours) }
          subject { TimeFrame.union([time_frame2, time_frame1]) }
          it { should eq [time_frame1, time_frame2] }
        end
        context 'that intersect at their boundaries' do
          let(:time_frame1) { TimeFrame.new(min: time, duration: + 2.hour) }
          let(:time_frame2) { time_frame1.shift_by(time_frame1.duration) }
          subject { TimeFrame.union([time_frame2, time_frame1]) }
          it do
            should eq [
              TimeFrame.new(min: time_frame1.min, max: time_frame2.max)
            ]
          end
        end
      end
    end

    it 'ignores any empty time frames' do
      expect(TimeFrame.union([TimeFrame::EMPTY, TimeFrame::EMPTY])).to eq []
    end
  end

  describe '.intersection' do
    it 'returns the intersection of all time frames' do
      time_frame1 = TimeFrame.new(min: Time.zone.local(2012), duration: 3.days)
      time_frame2 = time_frame1.shift_by(-1.day)
      time_frame3 = time_frame1.shift_by(-2.days)
      expect(TimeFrame.intersection([time_frame1, time_frame2, time_frame3]))
        .to eq TimeFrame.new(min: Time.zone.local(2012), duration: 1.day)
    end
    it 'is empty if the intersection is empty' do
      time_frame1 = TimeFrame.new(min: Time.zone.local(2012), duration: 1.days)
      time_frame2 = time_frame1.shift_by(-2.day)
      time_frame3 = time_frame1.shift_by(-4.days)
      expect(
        TimeFrame.intersection([time_frame1, time_frame2, time_frame3])
      ).to be_empty
    end
  end

  describe '#overlaps?' do
    let(:time_frame) { TimeFrame.new(min: time, duration: 3.hours) }
    context 'when self is equal to other' do
      let(:other) { time_frame.clone }
      subject { time_frame.overlaps?(other) }
      it { should be true }
    end
    context 'when self covers other' do
      let(:other) do
        TimeFrame.new(
          min: time_frame.min + 1.hour, max: time_frame.max - 1.hour
        )
      end
      subject { time_frame.overlaps?(other) }
      it { should be true }
    end
    context 'when other covers self' do
      let(:other) do
        TimeFrame.new(
          min: time_frame.min - 1.hour, max: time_frame.max + 1.hour
        )
      end
      subject { time_frame.overlaps?(other) }
      it { should be true }
    end
    context 'when self begins earlier than other' do
      context 'and they are disjoint' do
        let(:other) { time_frame.shift_by(-time_frame.duration - 1.hour) }
        subject { time_frame.overlaps?(other) }
        it { should be false }
      end
      context 'and they are overlapping' do
        let(:other) { time_frame.shift_by(-1.hours) }
        subject { time_frame.overlaps?(other) }
        it { should be true }
      end
      context 'and they intersect at their boundaries' do
        let(:other) { time_frame.shift_by(-time_frame.duration) }
        subject { time_frame.overlaps?(other) }
        it { should be false }
      end
    end
    context 'when other begins earlier than self' do
      context 'and they are disjoint' do
        let(:other) { time_frame.shift_by(time_frame.duration + 1.hour) }
        subject { time_frame.overlaps?(other) }
        it { should be false }
      end
      context 'and they are overlapping' do
        let(:other) { time_frame.shift_by(1.hours) }
        subject { time_frame.overlaps?(other) }
        it { should be true }
      end
      context 'and they intersect at their boundaries' do
        let(:other) { time_frame.shift_by(time_frame.duration) }
        subject { time_frame.overlaps?(other) }
        it { should be false }
      end
    end
    it 'returns false when self contains only one point' do
      singleton_time_frame = TimeFrame.new(min: time, max: time)
      time_frame = TimeFrame.new(min: time, duration: 1.hour)
      expect(singleton_time_frame.overlaps?(time_frame)).to be false
      expect(singleton_time_frame.overlaps?(singleton_time_frame)).to be false
      expect(singleton_time_frame.overlaps?(TimeFrame::EMPTY)).to be false
    end
    it 'returns false when self is empty' do
      singleton_time_frame = TimeFrame.new(min: time, max: time)
      time_frame = TimeFrame.new(min: time, duration: 1.hour)
      expect(TimeFrame::EMPTY.overlaps?(time_frame)).to be false
      expect(TimeFrame::EMPTY.overlaps?(singleton_time_frame)).to be false
      expect(TimeFrame::EMPTY.overlaps?(TimeFrame::EMPTY)).to be false
    end
    it 'returns false when other contains only one point' do
      singleton_time_frame = TimeFrame.new(min: time, max: time)
      time_frame = TimeFrame.new(min: time, duration: 1.hour)
      expect(time_frame.overlaps?(singleton_time_frame)).to be false
      expect(singleton_time_frame.overlaps?(singleton_time_frame)).to be false
      expect(TimeFrame::EMPTY.overlaps?(singleton_time_frame)).to be false
    end
    it 'returns false when other is empty' do
      singleton_time_frame = TimeFrame.new(min: time, max: time)
      time_frame = TimeFrame.new(min: time, duration: 1.hour)
      expect(time_frame.overlaps?(TimeFrame::EMPTY)).to be false
      expect(singleton_time_frame.overlaps?(TimeFrame::EMPTY)).to be false
      expect(TimeFrame::EMPTY.overlaps?(TimeFrame::EMPTY)).to be false
    end
  end

  describe '#&' do
    let(:time_frame) { TimeFrame.new(min: time, duration: 3.hours) }
    context 'when self is equal to other' do
      let(:other) { time_frame.clone }
      subject { time_frame & other }
      it { should eq time_frame }
    end
    context 'when self covers other' do
      let(:other) do
        TimeFrame.new(
          min: time_frame.min + 1.hour, max: time_frame.max - 1.hour
        )
      end
      subject { time_frame & other }
      it { should eq other }
    end
    context 'when other covers self' do
      let(:other) do
        TimeFrame.new(
          min: time_frame.min - 1.hour, max: time_frame.max + 1.hour
        )
      end
      subject { time_frame & other }
      it { should eq time_frame }
    end
    context 'when self begins earlier than other' do
      context 'and they are disjoint' do
        let(:other) { time_frame.shift_by(time_frame.duration + 1.hour) }
        subject { time_frame & other }
        it { should be_empty }
      end
      context 'and they are overlapping' do
        let(:other) { time_frame.shift_by(1.hour) }
        subject { time_frame & other }
        it { should eq TimeFrame.new(min: other.min, max: time_frame.max) }
      end
      context 'and they intersect at their boundaries' do
        let(:other) { time_frame.shift_by(time_frame.duration) }
        subject { time_frame & other }
        it { should eq TimeFrame.new(min: time_frame.max, max: time_frame.max) }
      end
    end
    context 'when other begins earlier than self' do
      context 'and they are disjoint' do
        let(:other) { time_frame.shift_by(-time_frame.duration - 1.hour) }
        subject { time_frame & other }
        it { should be_empty }
      end
      context 'and they are overlapping' do
        let(:other) { time_frame.shift_by(-1.hour) }
        subject { time_frame & other }
        it { should eq TimeFrame.new(min: time_frame.min, max: other.max) }
      end
      context 'and they intersect at their boundaries' do
        let(:other) { time_frame.shift_by(-time_frame.duration) }
        subject { time_frame & other }
        it { should eq TimeFrame.new(min: time_frame.min, max: time_frame.min) }
      end
    end
    it 'is empty time frame when self it empty' do
      expect(TimeFrame::EMPTY & time_frame).to eq TimeFrame::EMPTY
      expect(TimeFrame::EMPTY & TimeFrame::EMPTY).to eq TimeFrame::EMPTY
    end
    it 'is empty time frame when self it not empty and the argument is empty' do
      expect(time_frame & TimeFrame::EMPTY).to eq TimeFrame::EMPTY
    end
  end

  describe '#split_by_interval' do
    context 'when time frame duration is divisible by interval' do
      let(:time) { Time.new(2012, 1, 1) }
      let(:interval) { 1.day }
      let(:time_frame) do
        TimeFrame.new(min: time, duration: 7.days)
      end
      subject do
        time_frame.split_by_interval(interval)
      end

      describe '#size' do
        subject { super().size }
        it { should eq 7 }
      end
      (0..6).each do |day|
        it "should have the right borders on day #{day}" do
          expected = TimeFrame.new(min: time, duration: interval)
          expect(subject[day]).to eq expected.shift_by(day.days)
        end
      end
    end

    context 'when time frame duration is not divisible by interval' do
      let(:time) { Time.new(2012, 1, 1) }
      let(:interval) { 1.day }
      let(:time_frame) do
        TimeFrame.new(min: time, duration: 7.days + 12.hours)
      end
      subject do
        time_frame.split_by_interval(interval)
      end

      describe '#size' do
        subject { super().size }
        it { should eq 8 }
      end
      (0..6).each do |day|
        it "should have the right borders on day #{day}" do
          expected = TimeFrame.new(min: time, duration: interval)
          expect(subject[day]).to eq expected.shift_by(day.days)
        end
      end
      it 'has a smaller time_frame at the end' do
        expected = TimeFrame.new(min: time + 7.days, duration: 12.hours)
        expect(subject[7]).to eq expected
      end
    end

    it 'returns an empty array when self is empty' do
      expect(TimeFrame::EMPTY.split_by_interval(1.day)).to eq []
    end
  end

  describe '#shift_by' do
    let(:min) { time }
    let(:max) { time + 2.days }
    let(:time_frame) { TimeFrame.new(min: min, max: max) }
    context 'when shifting into the future' do
      subject { time_frame.shift_by(1.day) }

      describe '#min' do
        subject { super().min }
        it { should eq min + 1.day }
      end

      describe '#max' do
        subject { super().max }
        it { should eq max + 1.day }
      end
      it { should_not equal time_frame }
    end
    context 'when shifting into the past' do
      subject { time_frame.shift_by(-1.day) }

      describe '#min' do
        subject { super().min }
        it { should eq min - 1.day }
      end

      describe '#max' do
        subject { super().max }
        it { should eq max - 1.day }
      end
      it { should_not equal time_frame }
    end
    context 'when shifting by 0' do
      subject { time_frame.shift_by(0) }

      describe '#min' do
        subject { super().min }
        it { should eq min }
      end

      describe '#max' do
        subject { super().max }
        it { should eq max }
      end
      it { should_not equal time_frame }
    end
    context 'when shifting back and forth' do
      subject { time_frame.shift_by(-1.day).shift_by(1.day) }

      describe '#min' do
        subject { super().min }
        it { should eq min }
      end

      describe '#max' do
        subject { super().max }
        it { should eq max }
      end
      it { should_not equal time_frame }
    end
    it 'raises a TypeError when time frame is empty' do
      expect { TimeFrame::EMPTY.shift_by(1.day) }.to raise_error TypeError
    end
  end

  describe '#shift_to' do
    let(:duration) { 1.day }
    let(:min)      { Time.zone.local(2012, 1, 2) }
    let(:max)      { min + duration }
    let(:time_frame) { TimeFrame.new(min: min, max: max) }

    context 'when shifting to a future time' do
      let(:destination) { min + duration }
      subject { time_frame.shift_to(destination) }
      it { should_not equal time_frame }

      describe '#min' do
        subject { super().min }
        it { should eq destination }
      end

      describe '#max' do
        subject { super().max }
        it { should eq destination + duration }
      end
    end

    context 'when shifting to a past time' do
      let(:destination) { min - duration }
      subject { time_frame.shift_to(destination) }
      it { should_not equal time_frame }

      describe '#min' do
        subject { super().min }
        it { should eq destination }
      end

      describe '#max' do
        subject { super().max }
        it { should eq destination + duration }
      end
    end

    context 'when shifting to same time' do
      let(:destination) { min }
      subject { time_frame.shift_to(destination) }
      it { should_not equal time_frame }

      describe '#min' do
        subject { super().min }
        it { should eq destination }
      end

      describe '#max' do
        subject { super().max }
        it { should eq destination + duration }
      end
    end

    it 'raises a TypeError when time frame is empty' do
      expect do
        TimeFrame::EMPTY.shift_to(Time.zone.local(2012, 1, 2))
      end.to raise_error TypeError
    end
  end

  describe '#without' do
    let(:time_frame) { TimeFrame.new(min: time, duration: 10.hours) }
    context 'when the arguments do not intersect' do
      context 'and do not touch the boundaries' do
        let(:arg) do
          shift = time_frame.duration + 1.hour
          [
            TimeFrame.new(min: time - 2.hours, duration: 1.hour),
            TimeFrame.new(min: time + shift, duration: 1.hour)
          ]
        end
        subject { time_frame.without(*arg) }
        it { should eq [time_frame] }
      end
      context 'and they touch boundaries' do
        let(:arg) do
          [
            TimeFrame.new(min: time - 1.hour, duration: 1.hour),
            TimeFrame.new(min: time + time_frame.duration, duration: 1.hour)
          ]
        end
        subject { time_frame.without(*arg) }
        it { should eq [time_frame] }
      end
    end
    context 'when the arguments intersect' do
      context 'and the argument time_frames overlaps themself' do
        let(:arg) do
          [
            TimeFrame.new(min: time + 1.hour, duration: 2.hours),
            TimeFrame.new(min: time + 2.hours, duration: 2.hours)
          ]
        end
        let(:expected) do
          [
            TimeFrame.new(min: time_frame.min, duration: 1.hour),
            TimeFrame.new(min: time + 4.hours, max: time_frame.max)
          ]
        end
        subject { time_frame.without(*arg) }
        it { should eq expected }
      end
      context 'and they cover self' do
        let(:arg) do
          duration = 0.5 * time_frame.duration
          [
            TimeFrame.new(min: time, duration: duration),
            TimeFrame.new(min: time + duration, duration: duration)
          ]
        end
        subject { time_frame.without(*arg) }
        it { should eq [] }
      end
      context 'and they overlap at the boundaries' do
        let(:arg) do
          shift = time_frame.duration - 1.hour
          [
            TimeFrame.new(min: time - 1.hour, duration: 2.hour),
            TimeFrame.new(min: time + shift, duration: 2.hour)
          ]
        end
        let(:expected) do
          [
            TimeFrame.new(min: time_frame.min + 1.hour,
                          max: time_frame.max - 1.hour)
          ]
        end
        subject { time_frame.without(*arg) }
        it { should eq expected }
      end
      context 'and we have three time_frames in args overlaped by self' do
        context 'which are sorted' do
          let(:arg) do
            [
              TimeFrame.new(min: time + 1.hour, duration: 2.hour),
              TimeFrame.new(min: time + 4.hours, duration: 2.hour),
              TimeFrame.new(min: time + 7.hours, duration: 2.hour)
            ]
          end
          let(:expected) do
            [
              TimeFrame.new(min: time, max: time + 1.hour),
              TimeFrame.new(min: time + 3.hours, max: time + 4.hour),
              TimeFrame.new(min: time + 6.hours, max: time + 7.hours),
              TimeFrame.new(min: time + 9.hours, max: time + 10.hours)
            ]
          end
          subject { time_frame.without(*arg) }
          it { should eq expected }
        end
        context 'and they are unsorted' do
          let(:arg) do
            [
              TimeFrame.new(min: time + 4.hours, duration: 2.hour),
              TimeFrame.new(min: time + 1.hour, duration: 2.hour),
              TimeFrame.new(min: time + 7.hours, duration: 2.hour)
            ]
          end
          let(:expected) do
            [
              TimeFrame.new(min: time, max: time + 1.hour),
              TimeFrame.new(min: time + 3.hours, max: time + 4.hour),
              TimeFrame.new(min: time + 6.hours, max: time + 7.hours),
              TimeFrame.new(min: time + 9.hours, max: time + 10.hours)
            ]
          end
          subject { time_frame.without(*arg) }
          it { should eq expected }
        end
      end
    end

    it 'returns self (as a singleton array) if there are no arguments' do
      expect(time_frame.without).to eq [time_frame]
    end

    it 'returns an empty array if self is empty' do
      expect(TimeFrame::EMPTY.without(time_frame)).to eq []
    end

    it 'ignores empty time ranges within the arguments' do
      expect(time_frame.without(TimeFrame::EMPTY)).to eq [time_frame]
    end
  end

  describe '.covering_time_frame_for' do
    context 'for a single time frame' do
      let(:time_frame) { TimeFrame.new(min: time, duration: 1.hour) }
      subject { TimeFrame.covering_time_frame_for([time_frame]) }
      it { should eq time_frame }
    end

    context 'for multiple time frames' do
      let(:time_frame1) { TimeFrame.new(min: time, duration: 2.hours) }
      let(:time_frame2) { time_frame1.shift_by(-1.hour) }
      let(:time_frame3) { time_frame1.shift_by(3.hours) }
      subject do
        TimeFrame.covering_time_frame_for(
          [time_frame1, time_frame2, time_frame3]
        )
      end

      describe '#min' do
        subject { super().min }
        it { should eq time_frame2.min }
      end

      describe '#max' do
        subject { super().max }
        it { should eq time_frame3.max }
      end
    end

    it 'returns the empty time frame if the array is empty' do
      expect(TimeFrame.covering_time_frame_for([])).to eq TimeFrame::EMPTY
    end

    it 'ignores empty time frames' do
      time_frame = TimeFrame.new(min: time, duration: 2.hours)
      expect(
        TimeFrame.covering_time_frame_for([time_frame, TimeFrame::EMPTY])
      ).to eq time_frame
    end
  end

  describe '.each_overlap' do
    # Visualization of example input:
    #
    # array1:       |---|-------|   |-------|-----------|
    # array2:               |-----------|   |---|   |---|   |---|
    #
    #               0   1   2   3   4   5   6   7   8   9  10  11

    let(:array1) do
      [
        TimeFrame.new(min: time, max: time + 1.hour),
        TimeFrame.new(min: time + 1.hour, max: time + 3.hours),
        TimeFrame.new(min: time + 4.hours, max: time + 6.hours),
        TimeFrame.new(min: time + 6.hours, max: time + 9.hours)
      ]
    end

    let(:array2) do
      [
        TimeFrame.new(min: time + 2.hours, max: time + 5.hour),
        TimeFrame.new(min: time + 6.hour, max: time + 7.hours),
        TimeFrame.new(min: time + 8.hours, max: time + 9.hours),
        TimeFrame.new(min: time + 10.hours, max: time + 11.hours),
        TimeFrame::EMPTY
      ]
    end

    it 'yields the block for each overlap' do
      overlaps = []
      TimeFrame.each_overlap(array1, array2) { |a, b| overlaps << [a, b] }
      expect(overlaps).to eq [
        [array1[1], array2[0]],
        [array1[2], array2[0]],
        [array1[3], array2[1]],
        [array1[3], array2[2]]
      ]
    end

    it 'still works when switching arguments' do
      overlaps = []
      TimeFrame.each_overlap(array2, array1) { |a, b| overlaps << [a, b] }
      expect(overlaps).to eq [
        [array2[0], array1[1]],
        [array2[0], array1[2]],
        [array2[1], array1[3]],
        [array2[2], array1[3]]
      ]
    end

    it 'works if first array is empty' do
      overlaps = []
      TimeFrame.each_overlap([], array2) { |a, b| overlaps << [a, b] }
      expect(overlaps).to be_empty
    end

    it 'works if second array is empty' do
      overlaps = []
      TimeFrame.each_overlap(array1, []) { |a, b| overlaps << [a, b] }
      expect(overlaps).to be_empty
    end
  end

  describe '#inspect' do
    it 'works for a TimeFrame with same min and max' do
      time = Time.now
      expected = "#{time}..#{time}"
      tr = TimeFrame.new(min: time, max: time)
      actual = tr.inspect
      expect(actual).to eq expected
    end

    it 'works for a TimeFrame created with min and max' do
      min = Time.now
      max = min + 10.minutes
      expected = "#{min}..#{max}"
      tr = TimeFrame.new(min: min, max: max)
      actual = tr.inspect
      expect(actual).to eq expected
    end

    it 'works for a TimeFrame created with min and duration' do
      min = Time.now
      max = min + 10.minutes
      expected = "#{min}..#{max}"
      tr = TimeFrame.new(min: min, duration: 10.minutes)
      actual = tr.inspect
      expect(actual).to eq expected
    end

    it 'is overridden for empty time frames' do
      expect(TimeFrame::EMPTY.inspect).to eq 'EMPTY'
    end
  end

  describe '#before?' do
    context 'when dealing with Time instances' do
      it 'returns false if time is before time frame' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        some_time = time - 1.hour
        expect(time_frame.before?(some_time)).to be false
      end

      it 'returns false if time is on time frame min value' do
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        expect(time_frame.before?(time)).to be false
      end

      it 'returns false if time is on time frame max value' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time - 1.hour, max: time)
        expect(time_frame.before?(time)).to be false
      end

      it 'returns false if time is covered by time frame' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        some_time = time + 2.hours
        expect(time_frame.before?(some_time)).to be false
      end

      it 'returns true if time is behind time frame max value' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        some_time = time + 10.hours
        expect(time_frame.before?(some_time)).to be true
      end
    end

    context 'when dealing with TimeFrame instances' do
      it 'returns false if time frame in question is before time frame' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(min: Time.new(2011), duration: 1.hour)
        expect(time_frame.before?(other)).to be false
      end

      it 'returns false if time frame in question ends on min value' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(min: Time.new(2011), max: time_frame.min)
        expect(time_frame.before?(other)).to be false
      end

      it 'returns false if time frame in question is covered by frame' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(
          min: time_frame.min + 1.hour,
          max: time_frame.min + 2.hours
        )
        expect(time_frame.before?(other)).to be false
      end

      it 'returns false if time frame in question starts at max' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(
          min: time_frame.max,
          max: time_frame.max + 2.hours
        )
        expect(time_frame.before?(other)).to be false
      end

      it 'returns true if time frame in question lies after time frame' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(
          min: time_frame.max + 1.hour,
          max: time_frame.max + 2.hours
        )
        expect(time_frame.before?(other)).to be true
      end
    end
  end

  describe '#after?' do
    context 'when dealing with Time instances' do
      it 'returns true if time is before time frame' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        some_time = time - 1.hour
        expect(time_frame.after?(some_time)).to be true
      end

      it 'returns false if time is on time frame min value' do
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        expect(time_frame.after?(time)).to be false
      end

      it 'returns false if time is on time frame max value' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time - 1.hour, max: time)
        expect(time_frame.after?(time)).to be false
      end

      it 'returns false if time is covered by time frame' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        some_time = time + 2.hours
        expect(time_frame.after?(some_time)).to be false
      end

      it 'returns false if time is behind time frame max value' do
        time = Time.new(2012, 2, 1)
        time_frame = TimeFrame.new(min: time, duration: 3.hours)
        some_time = time + 10.hours
        expect(time_frame.after?(some_time)).to be false
      end
    end

    context 'when dealing with TimeFrame instances' do
      it 'returns false if time frame in question is after time frame' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(min: Time.new(2014), duration: 1.hour)
        expect(time_frame.after?(other)).to be false
      end

      it 'returns false if time frame in question ends on min value' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(min: Time.new(2011), max: time_frame.min)
        expect(time_frame.after?(other)).to be false
      end

      it 'returns false if time frame in question is covered by frame' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(
          min: time_frame.min + 1.hour,
          max: time_frame.min + 2.hours
        )
        expect(time_frame.after?(other)).to be false
      end

      it 'returns false if time frame in question starts at max' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(
          min: time_frame.max,
          max: time_frame.max + 2.hours
        )
        expect(time_frame.after?(other)).to be false
      end

      it 'returns true if time frame in question is before time frame' do
        time_frame = TimeFrame.new(min: Time.new(2012, 2, 1), duration: 2.hours)
        other = TimeFrame.new(
          min: time_frame.min - 10.hours,
          max: time_frame.min - 5.hours
        )
        expect(time_frame.after?(other)).to be true
      end
    end
  end
end
