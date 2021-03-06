
require 'ffi_yajl/ffi'

module FFI_Yajl
  module FFI
    module Parser

        def set_value(val)
          case stack.last
          when Hash
            raise FFI_Yajl::ParseError.new("internal error: missing key in parse") if key.nil?
            stack.last[key] = val
          when Array
            stack.last.push(val)
          else
            raise FFI_Yajl::ParseError.new("internal error: object not a hash or array")
          end
        end

        def stack_pop
          if stack.length > 1
            set_value( stack.pop )
          else
            @finished = stack.pop
          end
        end

        def key_push
          key_stack.push(key)
        end

        def key_pop
          @key = key_stack.pop()
        end


      def setup_callbacks
        @null_callback = ::FFI::Function.new(:int, [:pointer]) do |ctx|
          set_value(nil)
          1
        end
        @boolean_callback = ::FFI::Function.new(:int, [:pointer, :int]) do |ctx, boolval|
          set_value(boolval == 1 ? true : false)
          1
        end
        @integer_callback = ::FFI::Function.new(:int, [:pointer, :long_long]) do |ctx, intval|
          set_value(intval)
          1
        end
        @number_callback = ::FFI::Function.new(:int, [:pointer, :string, :size_t ]) do |ctx, stringval, stringlen|
          s = stringval.slice(0,stringlen)
          s.force_encoding('UTF-8') if defined? Encoding
          # XXX: I can't think of a better way to do this right now.  need to call to_f if and only if its a float.
          v = ( s =~ /[\.eE]/ ) ? s.to_f : s.to_i
          set_value(v)
          1
        end
        @double_callback = ::FFI::Function.new(:int, [:pointer, :double]) do |ctx, doubleval|
          set_value(doubleval)
          1
        end
        @string_callback = ::FFI::Function.new(:int, [:pointer, :string, :size_t]) do |ctx, stringval, stringlen|
          s = stringval.slice(0,stringlen)
          s.force_encoding('UTF-8') if defined? Encoding
          set_value(s)
          1
        end
        @start_map_callback = ::FFI::Function.new(:int, [:pointer]) do |ctx|
          key_push  # for key => { } case, save the key
          stack.push(Hash.new)
          1
        end
        @map_key_callback = ::FFI::Function.new(:int, [:pointer, :string, :size_t]) do |ctx, key, keylen|
          s = key.slice(0,keylen)
          s.force_encoding('UTF-8') if defined? Encoding
          self.key = @opts[:symbolize_keys] ? s.to_sym : s
          1
        end
        @end_map_callback = ::FFI::Function.new(:int, [:pointer]) do |ctx|
          key_pop
          stack_pop
          1
        end
        @start_array_callback = ::FFI::Function.new(:int, [:pointer]) do |ctx|
          key_push  # for key => [ ] case, save the key
          stack.push(Array.new)
          1
        end
        @end_array_callback = ::FFI::Function.new(:int, [:pointer]) do |ctx|
          key_pop
          stack_pop
          1
        end
      end


      def do_yajl_parse(str, yajl_opts = {})
        setup_callbacks
        callback_ptr = ::FFI::MemoryPointer.new(::FFI_Yajl::YajlCallbacks)
        callbacks = ::FFI_Yajl::YajlCallbacks.new(callback_ptr)
        callbacks[:yajl_null] = @null_callback
        callbacks[:yajl_boolean] = @boolean_callback
        callbacks[:yajl_integer] = @integer_callback
        callbacks[:yajl_double] = @double_callback
        callbacks[:yajl_number] = @number_callback
        callbacks[:yajl_string] = @string_callback
        callbacks[:yajl_start_map] = @start_map_callback
        callbacks[:yajl_map_key] = @map_key_callback
        callbacks[:yajl_end_map] = @end_map_callback
        callbacks[:yajl_start_array] = @start_array_callback
        callbacks[:yajl_end_array] = @end_array_callback
        yajl_handle = ::FFI_Yajl.yajl_alloc(callback_ptr, nil, nil)

        # configure the yajl parser
        if yajl_opts[:yajl_allow_comments]
          ::FFI_Yajl.yajl_config(yajl_handle, :yajl_allow_comments, :int, 1)
        end
        if yajl_opts[:yajl_dont_validate_strings]
          ::FFI_Yajl.yajl_config(yajl_handle, :yajl_dont_validate_strings, :int, 1)
        end
        if yajl_opts[:yajl_allow_trailing_garbage]
          ::FFI_Yajl.yajl_config(yajl_handle, :yajl_allow_trailing_garbage, :int, 1)
        end
        if yajl_opts[:yajl_allow_multiple_values]
          ::FFI_Yajl.yajl_config(yajl_handle, :yajl_allow_multiple_values, :int, 1)
        end
        if yajl_opts[:yajl_allow_partial_values]
          ::FFI_Yajl.yajl_config(yajl_handle, :yajl_allow_partial_values, :int, 1)
        end

        if ( stat = ::FFI_Yajl.yajl_parse(yajl_handle, str, str.bytesize) != :yajl_status_ok )
          # FIXME: dup the error and call yajl_free_error?
          error = ::FFI_Yajl.yajl_get_error(yajl_handle, 1, str, str.bytesize)
          raise ::FFI_Yajl::ParseError.new(error)
        end
        if ( stat = FFI_Yajl.yajl_complete_parse(yajl_handle) != :yajl_status_ok )
          # FIXME: dup the error and call yajl_free_error?
          error = ::FFI_Yajl.yajl_get_error(yajl_handle, 1, str, str.bytesize)
          raise ::FFI_Yajl::ParseError.new(error)
        end
        finished
      ensure
        ::FFI_Yajl.yajl_free(yajl_handle) if yajl_handle
      end
    end
  end
end

