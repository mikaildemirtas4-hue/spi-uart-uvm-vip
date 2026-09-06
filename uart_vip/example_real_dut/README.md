# UART VIP - Gerçek DUT Entegrasyon Örneği

Bu klasör, `uart_vip`'i **gerçek, sentezlenebilir bir RTL DUT'a** (basit bir
UART çekirdeği) nasıl bağlayacağını uçtan uca gösterir. Önceki `example/`
klasöründeki loopback demosundan farkı: burada karşı tarafta gerçek bir
Verilog modülü var, VIP-to-VIP değil.

## Dizin yapısı

```
example_real_dut/
├── rtl/
│   └── uart_core.sv        # Gerçek DUT - 16x oversample'lı, sentezlenebilir 8N1 UART çekirdeği
├── tb/
│   ├── uart_reg_if.sv       # DUT'un paralel tx_data/rx_data portu için clocking interface
│   ├── uart_reg_bfm.sv      # O interface'i kullanan küçük BFM (VIP'in bir parçası DEĞİL)
│   ├── uart_dut_env.sv      # VIP agent'larını DUT pinlerine bağlayan environment
│   ├── uart_dut_test.sv     # DUT'un hem alıcısını hem vericisini test eden senaryo
│   ├── uart_dut_pkg.sv
│   └── tb_top.sv            # <-- ASIL ENTEGRASYON NOKTASI, DUT instantiation burada
└── sim/
    └── questa.do            # Questa/ModelSim derleme + çalıştırma betiği
```

## Çalıştırmak için

```bash
cd example_real_dut/sim
vsim -c -do questa.do
```

GUI ile görmek istersen `vsim -do questa.do` (batch bayrağı olmadan) çalıştır.

## Entegrasyonun kalbi: `tb_top.sv`

Sorunun kaynağı genelde şu satırlardı - port map'i **doğrudan görmek**:

```systemverilog
uart_core dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .tx_data      (reg_if.tx_data),
    .tx_valid     (reg_if.tx_valid),
    .tx_ready     (reg_if.tx_ready),
    .tx_serial    (line_from_dut.line),   // DUT bu VIP telini SÜRER
    .rx_serial    (line_into_dut.line),   // VIP bu DUT girişini SÜRER
    .rx_data      (reg_if.rx_data),
    .rx_valid     (reg_if.rx_valid),
    .rx_frame_err (reg_if.rx_frame_err)
);
```

Yani: **VIP'in `uart_if.line` sinyali, DUT'un fiziksel pinine tam olarak bir
port-map satırıyla bağlanıyor.** Başka hiçbir şeye gerek yok - VIP kendi
başına DUT'un var olduğundan haberdar bile değil, sadece kendisine
bağlanan teli sürüyor/dinliyor.

## Kendi DUT'una uyarlamak için yapman gerekenler

1. `rtl/uart_core.sv`'yi kendi DUT modülünle değiştir (veya var olan DUT'unu
   `rtl/` altına ekle).
2. `tb_top.sv` içindeki `uart_core dut (...)` instantiation'ını kendi
   modülünün port isimleriyle güncelle. Kritik olan sadece iki bağlantı:
   - DUT'un serial RX girişi → `line_into_dut.line`
   - DUT'un serial TX çıkışı → `line_from_dut.line`
3. DUT'un paralel/register tarafı senin DUT'unda farklıysa (örneğin AXI/APB
   arkasındaysa), `uart_reg_if.sv` + `uart_reg_bfm.sv` ikilisini o arayüze
   göre yeniden yaz - mantık aynı: küçük bir clocking-block interface + onu
   kullanan birkaç task'lık bir BFM sınıfı.
4. `uart_dut_env.sv` içindeki `tx_cfg.baud_rate` / `num_data_bits` / `parity`
   / `num_stop_bits` alanlarını DUT'unun gerçek konfigürasyonuyla eşleştir.
5. `sim/questa.do` içindeki dosya yollarını kendi proje yapına göre güncelle
   (`$VIP_DIR`, `$DUT_DIR` değişkenleri).

## Neden iki ayrı `uart_if`?

UART tek yönlü, noktadan noktaya bir hat olduğu için (SPI'daki paylaşımlı
bus gibi değil) bir yönü sürecek agent ile diğer yönü dinleyecek agent
fiziksel olarak aynı telde olamaz - biri DUT'a giden, biri DUT'tan gelen
olmak üzere iki bağımsız tel lazım. `uart_vip/README.md`'de bu ayrım daha
detaylı anlatılıyor.

## Bu örnek neyi kanıtlıyor?

- `test_dut_receiver()`: VIP'in TX agent'ı DUT'un `rx_serial` pinine rastgele
  byte'lar gönderiyor, DUT'un kendi decode ettiği `rx_data`/`rx_valid`
  register çıkışı okunup karşılaştırılıyor → **DUT'un alıcısını** doğruluyor.
- `test_dut_transmitter()`: `reg_bfm` DUT'un `tx_data` register portuna
  byte itiyor, VIP'in RX agent'ı DUT'un `tx_serial` pininde ne çıktığını
  çözüp `uvm_tlm_analysis_fifo` üzerinden test'e ulaştırıyor → **DUT'un
  vericisini** doğruluyor.

Yani VIP artık sadece kendi kendine konuşmuyor - gerçek RTL'in her iki
yönünü de bağımsız olarak test ediyor.
