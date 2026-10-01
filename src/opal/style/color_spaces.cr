module Opal
  # Color space conversion engine providing exact transformations between
  # sRGB, CIE XYZ (D65), CIELAB (L*a*b*), Oklab / Oklch, CMYK, HSL, and HSV.
  module ColorSpaces
    # D65 standard illuminant reference white points (2° standard observer)
    D65_X = 0.95047_f64
    D65_Y = 1.00000_f64
    D65_Z = 1.08883_f64

    # Converts standard sRGB [0..255] to linear RGB [0.0..1.0]
    def self.srgb_to_linear(c : Float64) : Float64
      c <= 0.04045 ? (c / 12.92) : (((c + 0.055) / 1.055) ** 2.4)
    end

    # Converts linear RGB [0.0..1.0] to standard sRGB [0.0..1.0]
    def self.linear_to_srgb(c : Float64) : Float64
      c <= 0.0031308 ? (c * 12.92) : (1.055 * (c ** (1.0 / 2.4)) - 0.055)
    end

    # -------------------------------------------------------------------------
    # CIE XYZ (D65)
    # -------------------------------------------------------------------------

    # Converts sRGB [0..255] to CIE XYZ [0.0..1.0, 0.0..1.0, 0.0..1.0]
    def self.rgb_to_xyz(r : Int, g : Int, b : Int) : {Float64, Float64, Float64}
      r_lin = srgb_to_linear(r.to_f / 255.0)
      g_lin = srgb_to_linear(g.to_f / 255.0)
      b_lin = srgb_to_linear(b.to_f / 255.0)

      x = r_lin * 0.4124564 + g_lin * 0.3575761 + b_lin * 0.1804375
      y = r_lin * 0.2126729 + g_lin * 0.7151522 + b_lin * 0.0721750
      z = r_lin * 0.0193339 + g_lin * 0.1191920 + b_lin * 0.9503041

      {x, y, z}
    end

    # Converts CIE XYZ to sRGB [0..255]
    def self.xyz_to_rgb(x : Float64, y : Float64, z : Float64) : {UInt8, UInt8, UInt8}
      r_lin = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
      g_lin = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
      b_lin = x * 0.0556434 + y * -0.2040259 + z * 1.0572252

      r = (linear_to_srgb(r_lin).clamp(0.0, 1.0) * 255.0).round.to_u8
      g = (linear_to_srgb(g_lin).clamp(0.0, 1.0) * 255.0).round.to_u8
      b = (linear_to_srgb(b_lin).clamp(0.0, 1.0) * 255.0).round.to_u8

      {r, g, b}
    end

    # -------------------------------------------------------------------------
    # CIELAB (L*a*b*)
    # -------------------------------------------------------------------------

    private def self.lab_f(t : Float64) : Float64
      delta = 6.0 / 29.0
      t > (delta ** 3.0) ? (t ** (1.0 / 3.0)) : (t / (3.0 * delta * delta) + 4.0 / 29.0)
    end

    private def self.lab_f_inv(t : Float64) : Float64
      delta = 6.0 / 29.0
      t > delta ? (t ** 3.0) : (3.0 * delta * delta * (t - 4.0 / 29.0))
    end

    # Converts sRGB [0..255] to CIELAB: L* in [0..100], a* in [-128..127], b* in [-128..127]
    def self.rgb_to_lab(r : Int, g : Int, b : Int) : {Float64, Float64, Float64}
      x, y, z = rgb_to_xyz(r, g, b)

      fx = lab_f(x / D65_X)
      fy = lab_f(y / D65_Y)
      fz = lab_f(z / D65_Z)

      l = (116.0 * fy - 16.0).clamp(0.0, 100.0)
      a = 500.0 * (fx - fy)
      b_val = 200.0 * (fy - fz)

      {l, a, b_val}
    end

    # Converts CIELAB (L*, a*, b*) to sRGB [0..255]
    def self.lab_to_rgb(l : Float64, a : Float64, b : Float64) : {UInt8, UInt8, UInt8}
      fy = (l + 16.0) / 116.0
      fx = fy + (a / 500.0)
      fz = fy - (b / 200.0)

      x = D65_X * lab_f_inv(fx)
      y = D65_Y * lab_f_inv(fy)
      z = D65_Z * lab_f_inv(fz)

      xyz_to_rgb(x, y, z)
    end

    # -------------------------------------------------------------------------
    # Oklab & Oklch (Ottosson 2020 / CSS Color Module 4)
    # -------------------------------------------------------------------------

    private def self.cbrt_signed(x : Float64) : Float64
      x < 0.0 ? -((-x) ** (1.0 / 3.0)) : (x ** (1.0 / 3.0))
    end

    # Converts sRGB [0..255] to Oklab: L in [0.0..1.0], a in [-0.4..0.4], b in [-0.4..0.4]
    def self.rgb_to_oklab(r : Int, g : Int, b : Int) : {Float64, Float64, Float64}
      r_lin = srgb_to_linear(r.to_f / 255.0)
      g_lin = srgb_to_linear(g.to_f / 255.0)
      b_lin = srgb_to_linear(b.to_f / 255.0)

      l_prime = 0.4122214708 * r_lin + 0.5363325363 * g_lin + 0.0514459929 * b_lin
      m_prime = 0.2119034982 * r_lin + 0.6806995451 * g_lin + 0.1073969566 * b_lin
      s_prime = 0.0883024619 * r_lin + 0.2817188376 * g_lin + 0.6299787005 * b_lin

      l_ = cbrt_signed(l_prime)
      m_ = cbrt_signed(m_prime)
      s_ = cbrt_signed(s_prime)

      ok_l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
      ok_a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
      ok_b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

      {ok_l.clamp(0.0, 1.0), ok_a, ok_b}
    end

    # Converts Oklab (L, a, b) to sRGB [0..255]
    def self.oklab_to_rgb(l : Float64, a : Float64, b : Float64) : {UInt8, UInt8, UInt8}
      l_ = l + 0.3963377774 * a + 0.2158037573 * b
      m_ = l - 0.1055613458 * a - 0.0638541728 * b
      s_ = l - 0.0894841775 * a - 1.2914855480 * b

      l_lin = l_ ** 3.0
      m_lin = m_ ** 3.0
      s_lin = s_ ** 3.0

      r_lin = 4.0767416621 * l_lin - 3.3077115913 * m_lin + 0.2309699292 * s_lin
      g_lin = -1.2684380046 * l_lin + 2.6097574011 * m_lin - 0.3413193965 * s_lin
      b_lin = -0.0041960863 * l_lin - 0.7034186147 * m_lin + 1.7076147010 * s_lin

      r = (linear_to_srgb(r_lin).clamp(0.0, 1.0) * 255.0).round.to_u8
      g = (linear_to_srgb(g_lin).clamp(0.0, 1.0) * 255.0).round.to_u8
      b = (linear_to_srgb(b_lin).clamp(0.0, 1.0) * 255.0).round.to_u8

      {r, g, b}
    end

    # Converts sRGB [0..255] to Oklch: L in [0.0..1.0], C in [0.0..0.4], h in [0.0..360.0°]
    def self.rgb_to_oklch(r : Int, g : Int, b : Int) : {Float64, Float64, Float64}
      l, a, b_val = rgb_to_oklab(r, g, b)
      c = Math.sqrt(a * a + b_val * b_val)
      h = Math.atan2(b_val, a) * (180.0 / Math::PI)
      h = (h % 360.0 + 360.0) % 360.0
      {l, c, h}
    end

    # Converts Oklch (L, C, h) to sRGB [0..255]
    def self.oklch_to_rgb(l : Float64, c : Float64, h : Float64) : {UInt8, UInt8, UInt8}
      h_rad = h * (Math::PI / 180.0)
      a = c * Math.cos(h_rad)
      b = c * Math.sin(h_rad)
      oklab_to_rgb(l, a, b)
    end

    # -------------------------------------------------------------------------
    # CMYK (Cyan, Magenta, Yellow, Black)
    # -------------------------------------------------------------------------

    # Converts sRGB [0..255] to CMYK [0.0..1.0]
    def self.rgb_to_cmyk(r : Int, g : Int, b : Int) : {Float64, Float64, Float64, Float64}
      rf = r.to_f / 255.0
      gf = g.to_f / 255.0
      bf = b.to_f / 255.0

      k = 1.0 - Math.max(rf, Math.max(gf, bf))
      if k >= 0.9999
        {0.0, 0.0, 0.0, 1.0}
      else
        c = (1.0 - rf - k) / (1.0 - k)
        m = (1.0 - gf - k) / (1.0 - k)
        y = (1.0 - bf - k) / (1.0 - k)
        {c.clamp(0.0, 1.0), m.clamp(0.0, 1.0), y.clamp(0.0, 1.0), k.clamp(0.0, 1.0)}
      end
    end

    # Converts CMYK [0.0..1.0] to sRGB [0..255]
    def self.cmyk_to_rgb(c : Float64, m : Float64, y : Float64, k : Float64) : {UInt8, UInt8, UInt8}
      r = ((1.0 - c) * (1.0 - k) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      g = ((1.0 - m) * (1.0 - k) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      b = ((1.0 - y) * (1.0 - k) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      {r, g, b}
    end

    # -------------------------------------------------------------------------
    # HSL & HSV
    # -------------------------------------------------------------------------

    # Converts sRGB [0..255] to HSL: H in [0..360°], S in [0.0..1.0], L in [0.0..1.0]
    def self.rgb_to_hsl(r : Int, g : Int, b : Int) : {Float64, Float64, Float64}
      rf = r.to_f / 255.0
      gf = g.to_f / 255.0
      bf = b.to_f / 255.0

      max_val = Math.max(rf, Math.max(gf, bf))
      min_val = Math.min(rf, Math.min(gf, bf))
      delta = max_val - min_val

      l = (max_val + min_val) / 2.0

      if delta < 1e-6
        h = 0.0
        s = 0.0
      else
        s = l > 0.5 ? (delta / (2.0 - max_val - min_val)) : (delta / (max_val + min_val))

        h = if rf == max_val
              ((gf - bf) / delta) + (gf < bf ? 6.0 : 0.0)
            elsif gf == max_val
              ((bf - rf) / delta) + 2.0
            else
              ((rf - gf) / delta) + 4.0
            end
        h *= 60.0
      end

      {(h % 360.0 + 360.0) % 360.0, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0)}
    end

    # Converts HSL (H in [0..360°], S in [0.0..1.0], L in [0.0..1.0]) to sRGB [0..255]
    def self.hsl_to_rgb(h : Float64, s : Float64, l : Float64) : {UInt8, UInt8, UInt8}
      h_norm = (h % 360.0 + 360.0) % 360.0
      s_norm = s.clamp(0.0, 1.0)
      l_norm = l.clamp(0.0, 1.0)

      c = (1.0 - (2.0 * l_norm - 1.0).abs) * s_norm
      x = c * (1.0 - (((h_norm / 60.0) % 2.0) - 1.0).abs)
      m = l_norm - c / 2.0

      r_prime, g_prime, b_prime = case (h_norm / 60.0).to_i
                                  when 0 then {c, x, 0.0}
                                  when 1 then {x, c, 0.0}
                                  when 2 then {0.0, c, x}
                                  when 3 then {0.0, x, c}
                                  when 4 then {x, 0.0, c}
                                  else        {c, 0.0, x}
                                  end

      r = ((r_prime + m) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      g = ((g_prime + m) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      b = ((b_prime + m) * 255.0).round.to_u8.clamp(0_u8, 255_u8)

      {r, g, b}
    end

    # Converts sRGB [0..255] to HSV: H in [0..360°], S in [0.0..1.0], V in [0.0..1.0]
    def self.rgb_to_hsv(r : Int, g : Int, b : Int) : {Float64, Float64, Float64}
      rf = r.to_f / 255.0
      gf = g.to_f / 255.0
      bf = b.to_f / 255.0

      max_val = Math.max(rf, Math.max(gf, bf))
      min_val = Math.min(rf, Math.min(gf, bf))
      delta = max_val - min_val

      v = max_val
      s = max_val < 1e-6 ? 0.0 : (delta / max_val)

      h = if delta < 1e-6
            0.0
          elsif rf == max_val
            ((gf - bf) / delta) + (gf < bf ? 6.0 : 0.0)
          elsif gf == max_val
            ((bf - rf) / delta) + 2.0
          else
            ((rf - gf) / delta) + 4.0
          end
      h *= 60.0

      {(h % 360.0 + 360.0) % 360.0, s.clamp(0.0, 1.0), v.clamp(0.0, 1.0)}
    end

    # Converts HSV (H in [0..360°], S in [0.0..1.0], V in [0.0..1.0]) to sRGB [0..255]
    def self.hsv_to_rgb(h : Float64, s : Float64, v : Float64) : {UInt8, UInt8, UInt8}
      h_norm = (h % 360.0 + 360.0) % 360.0
      s_norm = s.clamp(0.0, 1.0)
      v_norm = v.clamp(0.0, 1.0)

      c = v_norm * s_norm
      x = c * (1.0 - (((h_norm / 60.0) % 2.0) - 1.0).abs)
      m = v_norm - c

      r_prime, g_prime, b_prime = case (h_norm / 60.0).to_i
                                  when 0 then {c, x, 0.0}
                                  when 1 then {x, c, 0.0}
                                  when 2 then {0.0, c, x}
                                  when 3 then {0.0, x, c}
                                  when 4 then {x, 0.0, c}
                                  else        {c, 0.0, x}
                                  end

      r = ((r_prime + m) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      g = ((g_prime + m) * 255.0).round.to_u8.clamp(0_u8, 255_u8)
      b = ((b_prime + m) * 255.0).round.to_u8.clamp(0_u8, 255_u8)

      {r, g, b}
    end
  end
end
