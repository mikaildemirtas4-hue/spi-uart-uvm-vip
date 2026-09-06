# SPI VIP - Gerçek DUT Entegrasyon Örneği

UART VIP'teki `example_real_dut/` ile aynı mantık: `spi_vip`'i gerçek,
sentezlenebilir bir RTL DUT'a (bir SPI slave çekirdeği) bağlayan uçtan uca
bir örnek.

## Dizin yapısı

```
example_real_dut/
├── rtl/
│   └── spi_slave_core.sv   # Gerçek DUT - Mode 0 sabit, sentezlenebilir SPI slave
├── tb/
│   ├── spi_reg_if.sv        # DUT'un paralel tx_data/rx_data portu için clocking interface
│   ├── spi_reg_bfm.sv       # O interface'i kullanan küçük BFM (VIP'in parçası DEĞİL)
│   ├── spi_dut_env.sv       # VIP'i (master rolünde) DUT pinlerine bağlayan environment
│   ├── spi_dut_test.sv      # Full-duplex transferle DUT'un hem TX hem RX tarafını tek seferde doğrulayan test
│   ├── spi_dut_pkg.sv
│   └── tb_top.sv            # <-- ASIL ENTEGRASYON NOKTASI, DUT instantiation burada
└── sim/
    └── questa.do
```

## Neden SPI'de UART'takinden farklı: tek geçişte iki yönlü doğrulama

UART tek yönlü iki hat gerektirdiği için DUT'un alıcısı ve vericisi ayrı
ayrı test ediliyordu. SPI ise doğası gereği **full-duplex** - MOSI ve MISO
aynı anda, aynı clock'la akıyor. Bu yüzden `spi_dut_test.sv` her transferde:

1. `reg_bfm.load_tx_byte(...)` ile DUT'un bir sonraki transferde MISO'ya
   basacağı byte'ı önceden yüklüyor.
2. VIP master'ı `spi_single_transfer_seq` ile rastgele bir byte MOSI'ye
   gönderiyor.
3. Aynı anda `reg_bfm.wait_for_rx_byte(...)` ile DUT'un MOSI'den ne
   çözdüğünü okuyor.
4. Tek transferde hem "DUT'un alıcısı doğru mu" hem "DUT'un vericisi doğru
   mu" kontrol ediliyor.

## Çalıştırmak için

```bash
cd example_real_dut/sim
vsim -c -do questa.do
```

## DUT hakkında

`spi_slave_core` sabit Mode 0 (CPOL=0, CPHA=0), 8-bit, MSB-first bir SPI
slave. Tüm SPI pinleri (`sclk`, `mosi`, `cs_n`) asenkron kabul edilip
sistem saatine (`clk`) senkronize ediliyor - gerçek bir tasarımda dışarıdan
gelen bir sinyali doğrudan clock/edge kaynağı olarak kullanmamak için
standart bir yaklaşım. `clk`'nin `sclk`'den en az ~5-10 kat hızlı olması
gerekiyor (örnekte 50 MHz clk / 5 MHz sclk = 10x).

Paralel port double-buffered: `tx_load` transfer ortasında bile güvenle
tetiklenebilir, DUT sadece bir sonraki transferin başında (`cs_n` düşünce)
yeni değeri "aktif" hale getiriyor - mid-transfer bozulma olmaz.

## Kendi DUT'una uyarlamak için

`uart_vip/example_real_dut/README.md`'deki checklist ile birebir aynı
mantık: `tb_top.sv`'deki DUT instantiation'ı kendi modülünle değiştir,
kritik olan sadece dört pin: `sclk`/`mosi`/`miso`/`cs_n`'in VIP'in
`spi_if` sinyallerine bağlanması. DUT'un mode'u Mode 0'dan farklıysa
`spi_dut_env.sv` içindeki `m_cfg.mode`'u güncelle.
