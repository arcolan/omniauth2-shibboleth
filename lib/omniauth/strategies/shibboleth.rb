module OmniAuth
  module Strategies
    class Shibboleth
      include OmniAuth::Strategy

      option :shib_session_id_field, 'Shib-Session-ID'
      option :shib_application_id_field, 'Shib-Application-ID'
      option :uid_field, 'eppn'
      option :name_field, 'displayName'
      option :info_fields, {}
      option :extra_fields, []
      option :debug, false
      option :fail_with_empty_uid, false
      option :request_type, :env
      option :multi_values, :raw

      def request_phase
        [ 
          302,
          {
            'Location' => script_name + callback_path + query_string,
            'Content-Type' => 'text/plain'
          },
          ["You are being redirected to Shibboleth SP/IdP for sign-in."]
        ]
      end

      def request_params
        case options.request_type
        when :env, 'env', :header, 'header'
          request.env
        when :params, 'params'
          request.params
        end
      end

      def request_param(key)
        multi_value_handler(
          case options.request_type
          when :env, 'env'
            request.env[key]
          when :header, 'header'
            request.env["HTTP_#{key.upcase.gsub('-', '_')}"]
          when :params, 'params'
            request.params[key]
          end
        )
      end

      def multi_value_handler(param_value)
        case options.multi_values
        when :raw, 'raw'
          param_value
        when :first, 'first'
          return nil if param_value.nil?
          param_value.split(";").first
        else
          eval(options.multi_values).call(param_value)
        end
      end

      def callback_phase
        if options.debug
          # dump attributes
          return [
            200,
            {
              'Content-Type' => 'text/plain'
            },
            ["!!!!! This message is generated by omniauth-shibboleth. To remove it set :debug to false. !!!!!\n#{request_params.sort.map {|i| "#{i[0]}: #{i[1]}" }.join("\n")}"]
          ]
        end
        return fail!(:no_shibboleth_session) unless (request_param(options.shib_session_id_field.to_s) || request_param(options.shib_application_id_field.to_s))
        return fail!(:empty_uid) if options.fail_with_empty_uid && option_handler(options.uid_field).empty?
        super
      end

      def option_handler(option_field)
        if option_field.class == String ||
          option_field.class == Symbol
          request_param(option_field.to_s)
        elsif option_field.class == Proc
          option_field.call(self.method(:request_param))
        end
      end
      
      uid do
        option_handler(options.uid_field)
      end

      info do
        res = {
          :name => option_handler(options.name_field)
        }
        options.info_fields.each_pair do |key, field|
          res[key] = option_handler(field)
        end
        res
      end

      extra do
        options.extra_fields.inject({:raw_info => {}}) do |hash, field|
          hash[:raw_info][field] = request_param(field.to_s)
          hash
        end
      end
    end
  end
end
