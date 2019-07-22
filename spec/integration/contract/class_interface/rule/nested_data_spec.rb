# frozen_string_literal: true

require 'dry/validation/contract'

RSpec.describe Dry::Validation::Contract, '.rule' do
  subject(:contract) { contract_class.new }

  context 'with a nested hash' do
    let(:contract_class) do
      Class.new(Dry::Validation::Contract) do
        params do
          required(:email).filled(:string)
          required(:address).hash do
            required(:city).value(:string)
            required(:street).value(:string)
            required(:zipcode).value(:string)
          end
        end

        rule(:email) do
          key.failure('invalid email') unless value.include?('@')
        end

        rule('address.zipcode') do
          key.failure('bad format') unless value.include?('-')
        end
      end
    end

    context 'when nested values fail both schema and rule checks' do
      it 'produces schema and rule errors' do
        expect(contract.(email: 'jane@doe.org', address: { city: 'NYC', zipcode: '123' }).errors.to_h)
          .to eql(address: { street: ['is missing'], zipcode: ['bad format'] })
      end
    end

    context 'when empty hash is provided' do
      it 'produces missing-key errors' do
        expect(contract.({}).errors.to_h).to eql(email: ['is missing'], address: ['is missing'])
      end
    end
  end

  context 'with a nested array' do
    let(:contract_class) do
      Class.new(Dry::Validation::Contract) do
        params do
          required(:address).hash do
            required(:phones).array(:string)
          end
        end

        rule('address.phones').each do
          key.failure('invalid phone') unless value.start_with?('+48')
        end
      end
    end

    context 'when one of the values fails' do
      it 'produces an error for the invalid value' do
        expect(contract.(address: { phones: ['+48123', '+47412', nil] }).errors.to_h)
          .to eql(address: { phones: { 1 => ['invalid phone'], 2 => ['must be a string'] } })
      end
    end
  end

  context 'with a deeply nested array' do
    let(:contract_class) do
      Class.new(Dry::Validation::Contract) do
        params do
          required(:addresses).array(:hash) do
            required(:phones).array(:string)
          end
        end

        register_macro(:pl_phone) do
          key.failure('invalid phone') unless value.start_with?('+48')
        end

        rule('addresses.phones').each(:pl_phone)
      end
    end

    context 'when one of the values fails' do
      it 'produces the errors for invalid values' do
        hash = {
          addresses: [
            { phones: ['+48123'] },
            { phones: ['+49123'] }
          ]
        }
        expect(contract.(hash).errors.to_h)
          .to eql(addresses: { 1 => { phones: { 0 => ['invalid phone'] } } })
      end
    end
  end
end
