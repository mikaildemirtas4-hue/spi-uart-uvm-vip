# SPI UVM VIP (Verification IP)

Her projede import edip kullanabileceğin, jenerik ve konfigüre edilebilir bir
SPI UVC (Universal Verification Component). Master ve slave rollerinin ikisini
de destekler, active/passive olarak konfigüre edilebilir, 4 SPI modunun
tamamını (CPOL/CPHA kombinasyonları) doğru zamanlamayla üretir.

## Dizin yapısı

```
spi_vip/
├── spi_if.sv                 # Fiziksel SPI arayüzü (sclk, mosi, miso, cs_n[])
├── spi_vip_pkg.sv            # Tek import noktası - tüm VIP burada toplanır
├── spi_transaction.sv        # Sequence item (tek kelimelik full-duplex transfer)
├── spi_config.sv             # Agent konfigürasyonu (mod, rol, timing, vs.)
├── spi_callback.sv           # Callback taban sınıfı (VIP koduna dokunmadan hook)
├── spi_coverage.sv           # Functional coverage (mode x width cross dahil)
├── spi_sequencer.sv
├── spi_driver_master.sv      # Master rolü - sclk/mosi/cs_n üretir, miso okur
├── spi_driver_slave.sv       # Slave rolü - sclk/cs_n'i izler, miso üretir
├── spi_monitor.sv            # Pasif izleyici - her iki rol için de çalışır
├── spi_agent.sv               # Config'e göre driver/sequencer/coverage kurar
├── seq_lib/
│   └── spi_seq_lib.sv        # Hazır sequence kütüphanesi
└── example/                  # Örnek kullanım (gerçek proje şablonu)
    ├── spi_env.sv
    ├── spi_loopback_test.sv
    ├── spi_example_pkg.sv
    └── tb_top.sv
```

> **Gerçek bir RTL DUT'a nasıl bağlanır?** `example_real_dut/` klasörüne
> bak - sentezlenebilir bir SPI slave çekirdeği + onu VIP'e bağlayan tam
> bir testbench + Questa `.do` betiği içeriyor. `example/` sadece VIP-to-VIP
> loopback; gerçek entegrasyonu görmek için `example_real_dut/README.md`'yi
> oku.

## Derleme sırası

`` `include `` tabanlı dosyalar ayrı derlenmez; simülatöre onları bulması
için `+incdir+` ile yol vermen yeterli. Sıra önemli:

```bash
# Örnek: Questa/VCS tarzı komut satırı
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv \
     spi_vip/spi_if.sv \
     +incdir+spi_vip spi_vip/spi_vip_pkg.sv \
     +incdir+spi_vip/example spi_vip/example/spi_example_pkg.sv \
     spi_vip/example/tb_top.sv

vsim -c tb_top +UVM_TESTNAME=spi_loopback_test -do "run -all"
```

## Kendi projene entegre etmek

1. `spi_vip/` klasörünü olduğu gibi projene kopyala (`example/` klasörü hariç -
   o sadece referans, VIP'in bir parçası değil).
2. Kendi env'inde:
   ```systemverilog
   spi_config cfg = spi_config::type_id::create("cfg");
   cfg.vif       = <senin virtual interface handle'ın>;
   cfg.is_master = 1;              // ya da 0, DUT slave mi master mı test ettiğine göre
   cfg.is_active = UVM_ACTIVE;     // ya da UVM_PASSIVE, sadece izlemek istiyorsan
   cfg.mode      = SPI_MODE_0;     // DUT hangi modu bekliyorsa onu seç
   cfg.num_cs    = 2;              // birden fazla slave select hattın varsa
   uvm_config_db#(spi_config)::set(this, "my_agent*", "cfg", cfg);

   my_agent = spi_agent::type_id::create("my_agent", this);
   ```
3. DUT bir SLAVE ise -> `cfg.is_master = 1` yapıp VIP'i master rolünde kullan.
   DUT bir MASTER ise -> `cfg.is_master = 0` yapıp VIP'i slave rolünde kullan
   ve `spi_slave_response_seq` ile cevap verilerini besle.
4. Sadece gözlem istiyorsan (örn. DUT'un kendi master/slave VIP'i zaten
   varken sadece coverage toplamak için) `cfg.is_active = UVM_PASSIVE` yap -
   agent sadece monitor + coverage kurar, driver/sequencer oluşturmaz.

## Callback ile genişletme (VIP kaynağına dokunmadan)

```systemverilog
class my_spi_cb extends spi_callback;
  `uvm_object_utils(my_spi_cb)
  function new(string name = "my_spi_cb"); super.new(name); endfunction

  virtual task post_transaction(uvm_component originator, spi_transaction tr);
    `uvm_info("MY_CB", $sformatf("gördüm: %s", tr.convert2string()), UVM_LOW)
  endtask
endclass

// test/env içinde:
my_spi_cb cb = my_spi_cb::type_id::create("cb");
uvm_callbacks#(spi_monitor, spi_callback)::add(my_agent.monitor, cb);
```

## Notlar / bilinçli tasarım kararları

- `spi_transaction` alan isimleri **bus-mutlak**: `mosi_data` her zaman MOSI
  telindeki veriyi, `miso_data` her zaman MISO telindeki veriyi temsil eder.
  Master sequence'leri `mosi_data`'yı doldurur, slave sequence'leri
  `miso_data`'yı doldurur - fiziksel tele bakınca kafa karıştırmayan tek
  yaklaşım bu.
- Monitor kelime genişliğini varsaymaz; CS düşene kadar biti sayar (gerçek
  SPI'da protokol seviyesinde framing yoktur).
- Master sürücüsündeki tüm zamanlama alanları (`clk_period_ns`,
  `cs_setup_time_ns`, ...) `spi_config` üzerinden proje bazında ayarlanabilir.
- `SPI_MAX_WIDTH` (`spi_vip_pkg.sv` içinde, varsayılan 32) VIP'in destekleyeceği
  azami kelime genişliğidir; her transfer bundan küçük veya eşit herhangi bir
  genişlik kullanabilir (`spi_transaction.num_bits`).
