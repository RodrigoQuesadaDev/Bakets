# frozen_string_literal: true

RSpec.describe Bakets do

  describe 'API' do

    describe 'Object creation' do

      describe 'Freeze' do

        describe 'setup' do

          describe 'freeze by default' do

          end

          describe 'do not freeze by default' do

          end
        end

        describe 'configuration' do

          describe 'enabled' do

            describe 'shallow' do
              test_classes do
                module Test
                  class ShallowFreeze
                    bakets freeze: :shallow

                    attr_reader :events

                    def initialize
                      @events = []
                      @events << :initialize
                    end

                    def post_initialize
                      @events << :post_initialize
                    end
                  end
                end
              end

            end

            describe 'deep' do

            end

            describe 'option shortcuts' do

            end
          end

          describe 'disabled' do

          end
        end
      end
    end
  end
end