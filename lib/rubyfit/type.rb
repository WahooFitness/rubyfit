# require "rubyfit/helpers"
require_relative 'helpers'

class RubyFit::Type
  attr_reader *%i(fit_id byte_count default_bytes)

  def initialize(opts = {})
    @val2bytes = opts[:val2bytes]
    @bytes2val = opts[:bytes2val]
    @rb2fit = opts[:rb2fit]
    @fit2rb = opts[:fit2rb]
    @default_bytes = opts[:default_bytes]
    @byte_count = opts[:byte_count]
    @fit_id = opts[:fit_id]
  end

  def val2bytes(val)
    result = val
    result = @rb2fit.call(result, self) if @rb2fit
    result = @val2bytes.call(result, self)
    result
  end

  def bytes2val(bytes, **opts)
    result = bytes
    result = @bytes2val.call(result, self, **opts)
    result = @fit2rb.call(result, self) if @fit2rb
    result
  end

  class << self
    include RubyFit::Helpers

    def integer(opts = {})
      unsigned = opts.delete(:unsigned)
      default = opts[:default]

      # Default (invalid) value for integers is the maximum positive value
      # given the bit length and whether the data is signed/unsigned
      unless default
        bit_count = opts[:byte_count] * 8
        bit_count -= 1 unless unsigned
        default = 2**bit_count - 1
      end

      new({
        default_bytes: num2bytes(default, opts[:byte_count]),
        val2bytes: ->(val, type) { num2bytes(val, type.byte_count) },
        bytes2val: ->(bytes, type, opts = {}) {
          value = bytes2num(bytes, type.byte_count, unsigned, opts[:big_endian])
          value == default ? nil : value
        },
      }.merge(opts))
    end

    # Base Types #
    
    def enum(opts = {})
      uint8(fit_id: 0x00)
    end

    def string(byte_count, opts = {})
      new({
        fit_id: 0x07,
        byte_count: byte_count,
        default_bytes: [0x00] * byte_count,
        val2bytes: ->(val, type) { str2bytes(val, type.byte_count) },
        bytes2val: ->(bytes, type, opts = {}) { bytes2str(bytes) },
      }.merge(opts))
    end

    def byte(byte_count, opts = {})
      new({
        fit_id: 0x0D,
        default_bytes: [0xFF] * length,
        val2bytes: ->(val) { val },
        bytes2val: ->(bytes) { bytes },
      }.merge(opts))
    end

    def sint8(opts = {})
      integer({unsigned: false, byte_count: 1, fit_id: 0x01}.merge(opts))
    end

    def uint8(opts = {})
      integer({unsigned: true, byte_count: 1, fit_id: 0x02}.merge(opts))
    end

    def sint16(opts = {})
      integer({unsigned: false, byte_count: 2, fit_id: 0x83}.merge(opts))
    end

    def uint16(opts = {})
      integer({unsigned: true, byte_count: 2, fit_id: 0x84}.merge(opts))
    end

    def sint32(opts = {})
      integer({unsigned: false, byte_count: 4, fit_id: 0x85}.merge(opts))
    end

    def uint32(opts = {})
      integer({unsigned: true, byte_count: 4, fit_id: 0x86}.merge(opts))
    end

    def sint64(opts = {})
      integer({unsigned: false, byte_count: 8, fit_id: 0x8E}.merge(opts))
    end

    def uint64(opts = {})
      integer({unsigned: true, byte_count: 8, fit_id: 0x8F}.merge(opts))
    end

    def uint8z(opts = {})
      integer({unsigned: true, default: 0, byte_count: 1, fit_id: 0x0A}.merge(opts))
    end

    def uint16z(opts = {})
      integer({unsigned: true, default: 0, byte_count: 2, fit_id: 0x8B}.merge(opts))
    end

    def uint32z(opts = {})
      integer({unsigned: true, default: 0, byte_count: 4, fit_id: 0x8C}.merge(opts))
    end

    def uint64z(opts = {})
      integer({unsigned: true, default: 0, byte_count: 8, fit_id: 0x90}.merge(opts))
    end

    # Derived types
    
    def timestamp
      uint32({
        rb2fit: ->(val, type) { unix2fit_timestamp(val) },
        fit2rb: ->(val, type) { val.nil? ? nil :  Time.at(fit2unix_timestamp(val)) }
      })
    end

    def semicircles
      sint32({
        rb2fit: ->(val, type) { deg2semicircles(val) },
        fit2rb: ->(val, type) { semicircles2deg(val) }
      })
    end

    def centimeters
      uint32({
        rb2fit: ->(val, type) { (val * 100).truncate },
        fit2rb: ->(val, type) { val.nil? ? nil : val / 100.0 }
      })
    end

    def altitude
      uint16({
        rb2fit: ->(val, type) {
          result = (val).truncate
          result
        },
        fit2rb: ->(val, type) {
          result = val.nil? ? nil : val
          result
        }
      })
    end

    def duration
      uint32({
        rb2fit: ->(val, type) { (val * 1000) },
        fit2rb: ->(val, type) { val.nil? ? nil :  val / 1000.0 }
      })
    end

    def enhanced_speed
      uint32({
               rb2fit: ->(val, type) { (val * 1000) },
               fit2rb: ->(val, type) { val.nil? ? nil : val / 1000.0 }
             })
    end

    def speed
      uint8({
               rb2fit: ->(val, type) { (val * 1000) },
               fit2rb: ->(val, type) { val.nil? ? nil :  val / 1000.0 }
             })
    end


    def grade
      sint16({
                rb2fit: ->(val, type) { (val * 100) },
                fit2rb: ->(val, type) { val.nil? ? nil :  val / 100.0 }
              })
    end

    def tss
      uint16({
               rb2fit: ->(val, type) { (val * 10) },
               fit2rb: ->(val, type) { val.nil? ? nil : val / 10.0 }
             })
    end

    def if
      uint16({
               rb2fit: ->(val, type) { (val * 1000) },
               fit2rb: ->(val, type) { val.nil? ? nil :  val / 1000.0 }
             })
    end

    def uint8_scale2
      uint8({
               rb2fit: ->(val, type) { (val * 2) },
               fit2rb: ->(val, type) { val.nil? ? nil :  val / 2 }
             })
    end

    def uint16_scale100
      uint16({
              rb2fit: ->(val, type) { (val * 100) },
              fit2rb: ->(val, type) { val.nil? ? nil :  val / 100 }
            })
    end

    def uint32_scale100
      uint32({
               rb2fit: ->(val, type) { (val * 100).truncate },
               fit2rb: ->(val, type) { val.nil? ? nil : val / 100.0 }
             })
    end


    def float64(opts = {})
      new({
            fit_id: 0x89,
            byte_count: 8,
            default_bytes: [0xFF] * 8,
            val2bytes: ->(val, type) { [val].pack("G").bytes },
            bytes2val: ->(bytes, type, opts = {}) { bytes.pack("C*").unpack1("G") },
          }.merge(opts))
    end

    def byte_array(length, opts = {})
      new({
            fit_id: 0x0D,
            byte_count: length,
            default_bytes: [0xFF] * length,
            val2bytes: ->(val, type) {
              val[0, length] + ([0xFF] * [length - val.length, 0].max)
            },
            bytes2val: ->(bytes, type, opts = {}) {
              bytes[0, length]
            },
          }.merge(opts))
    end
  end

  def self.uint32_array(length, opts = {})
    new({
          fit_id: 0x0D, # Assuming 0x0D is the correct fit_id for arrays
          byte_count: length * 4, # Assuming each hr_zone value is 4 bytes
          default_bytes: [0xFF] * (length * 4),
          val2bytes: ->(val, type) {
            val.flat_map { |v| [v * 1000].pack("L<").bytes } + ([0xFF] * [(length - val.length) * 4, 0].max)
          },
          bytes2val: ->(bytes, type, opts = {}) {
            bytes.each_slice(4).map { |slice| slice.pack("C*").unpack1("L<") / 1000.0 }
          },
        }.merge(opts))
  end
end
