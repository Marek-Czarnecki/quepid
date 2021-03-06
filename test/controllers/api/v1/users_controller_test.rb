# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class UsersControllerTest < ActionController::TestCase
      let(:matt) { users(:matt) }

      before do
        @controller = Api::V1::UsersController.new
      end

      describe 'Fetch user info' do
        describe 'when user is signed in' do
          before do
            login_user matt
          end

          test 'returns basic user info if user exists (self)' do
            @request.headers['Accept'] = 'application/vnd.quepid+json; version=1'
            get :show, id: matt.email
            assert_response :ok

            body = JSON.parse(response.body)

            assert body['email'] == matt.email
          end

          test 'returns basic user info if user exists (other user)' do
            doug = users(:doug)

            get :show, id: doug.email
            assert_response :ok

            body = JSON.parse(response.body)

            assert body['email'] == doug.email
            assert body['defaultScorerId'] == doug.default_scorer.id
          end

          test 'returns a not found error if user does not exist' do
            get :show, id: 'foo'
            assert_response :not_found
          end
        end

        describe 'when user is not signed in' do
          test 'returns an unauthorized error' do
            get :show, id: matt.email
            assert_response :unauthorized
          end
        end
      end

      describe "Update user's default scorer" do
        let(:scorer) { scorers(:valid) }

        before do
          login_user matt
        end

        test 'successfully updates default scorer' do
          patch :update, id: matt.email, user: { default_scorer_id: scorer.id }

          assert_response :success
          matt.reload
          assert_equal matt.default_scorer_id, scorer.id
          assert_equal matt.default_scorer, scorer
        end

        test 'successfully remove default scorer by setting the id to 0' do
          matt.default_scorer = scorer
          matt.save!

          patch :update, id: matt.email, user: { default_scorer_id: 0 }

          assert_response :success
          matt.reload
          assert_equal matt.default_scorer.name, Rails.application.config.quepid_default_scorer
        end

        test 'assigning a non existent scorer as default scorer' do
          matt.default_scorer = scorer
          matt.save!
          patch :update, id: matt.email, user: { default_scorer_id: 123 }

          assert_response :bad_request

          body = JSON.parse(response.body)
          # rubocop:disable Metrics/LineLength
          assert body['default_scorer_id'].include? I18n.t('activerecord.errors.models.user.attributes.default_scorer_id.existence')
          # rubocop:enable Metrics/LineLength

          matt.reload
          assert_equal matt.default_scorer, scorer
        end
      end

      describe "Update user's company" do
        before do
          login_user matt
        end

        test 'successfully updates company' do
          patch :update, id: matt.email, user: { company: 'OSC' }

          assert_response :success

          matt.reload
          assert 'OSC' == matt.company
        end
      end

      describe 'Search users' do
        describe 'when user is not an admin member' do
          let(:user) { users(:random) }

          before do
            login_user user
          end

          it 'returns an empty array' do
            get :index, email: 'manual@example.com'

            assert_response :ok

            assert_instance_of  Array,  json_response['users']
            assert_equal        [],     json_response['users']
          end
        end
      end
    end
  end
end
