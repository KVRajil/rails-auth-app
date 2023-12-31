require 'rails_helper'

RSpec.describe 'User::TwoFactorAuthentication', type: :request do
  let!(:user) { create(:user, email: 'test@gmail.com', password: 'Test@123', password_confirmation: 'Test@123', email_confirmed_at: Time.zone.now) }
  let(:json_response) { response.parsed_body.with_indifferent_access }
  let!(:headers) { { 'ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json' } }

  describe 'POST #generate_otp' do
    context 'Valid scenarios' do
      it 'should generate OTP' do
        token = JwtService.encode({ user_id: user.id })
        headers['Authorization'] = "Bearer #{token}"
        post('/users/generate_otp', headers: headers)

        expect(response).to have_http_status(:created)
        expect(json_response['message']).to eq('OTP sent to the email address')
      end
    end
  end

  describe 'POST #verify_otp' do
    context 'Valid scenarios' do
      it 'should return success on OTP verification' do
        token = JwtService.encode({ user_id: user.id })
        headers['Authorization'] = "Bearer #{token}"
        params = { otp: OtpService.new(user).generate }
        post('/users/verify_otp', headers: headers, params: params.to_json)

        expect(response).to have_http_status(:created)
        expect(json_response['token']).to be_present
      end
    end

    context 'Invalid scenarios' do
      it 'returns an unauthorized response' do
        post('/users/verify_otp', headers: headers)

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Unauthorized')
      end

      it 'returns invalid otp error' do
        token = JwtService.encode({ user_id: user.id })
        headers['Authorization'] = "Bearer #{token}"
        params = { otp: 'wrong otp' }
        post('/users/verify_otp', headers: headers, params: params.to_json)
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Invalid OTP')
      end
    end
  end

  describe 'PATCH #toggle_2fa' do
    context 'Valid scenarios' do
      it 'should disable the 2fa' do
        token = JwtService.encode({ user_id: user.id, otp_verified: true })
        headers['Authorization'] = "Bearer #{token}"
        params = { otp: OtpService.new(user).generate, password: 'Test@123', enable_2fa: false }
        patch('/users/toggle_2fa', headers: headers, params: params.to_json)

        expect(response).to have_http_status(:ok)
        expect(json_response['message']).to eq('2FA settings updated')
        expect(user.reload.is_two_factor_enabled).to eq(false)
      end
      it 'should enable the 2fa' do
        user.update!(is_two_factor_enabled: false)
        token = JwtService.encode({ user_id: user.id, otp_verified: true })
        headers['Authorization'] = "Bearer #{token}"
        params = { otp: OtpService.new(user).generate, password: 'Test@123', enable_2fa: true }
        patch('/users/toggle_2fa', headers: headers, params: params.to_json)

        expect(response).to have_http_status(:ok)
        expect(json_response['message']).to eq('2FA settings updated')
        expect(user.reload.is_two_factor_enabled).to eq(true)
      end
    end

    context 'Invalid scenarios' do
      it 'should should fail to update the 2fa & return Invalid password' do
        token = JwtService.encode({ user_id: user.id, otp_verified: true })
        headers['Authorization'] = "Bearer #{token}"
        params = { otp: OtpService.new(user).generate, password: 'Test@123Wrong', enable_2fa: false }
        patch('/users/toggle_2fa', headers: headers, params: params.to_json)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq('Invalid password')
      end
      it 'should should fail to update the 2fa & return Invalid OTP' do
        token = JwtService.encode({ user_id: user.id, otp_verified: true })
        headers['Authorization'] = "Bearer #{token}"
        params = { otp: 'wrong', password: 'Test@123', enable_2fa: false }
        patch('/users/toggle_2fa', headers: headers, params: params.to_json)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq('Invalid OTP')
      end
    end
  end
end
