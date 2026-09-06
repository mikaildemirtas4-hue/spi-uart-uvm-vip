# UART UVM VIP (Verification IP)

SPI VIP'iyle aynı mimari prensiplerle yazılmış, jenerik ve konfigüre
edilebilir bir UART UVC. Baud rate, veri biti sayısı (5-9), parity
(none/odd/even/mark/space) ve stop bit sayısı (1/1.5/2) tamamen
`uart_config` üzerinden ayarlanır.

## SPI VIP'ten temel fark

SPI paylaşılan bir bus'tır (tek master, ortak sclk); UART ise **tek yönlü,
noktadan noktaya** bir hattır. Bu yüzden "master/slave" yerine **TX/RX rolü**
var:

- **TX rolü** hattı sürer (start biti, data, parity, stop biti üretir).
- **RX rolü** hattı **hiçbir zaman sürmez** - sadece dinler ve çözer. Bu
  yüzden `is_active` sadece TX rolünde anlamlıdır; RX tarafı için
  `UVM_ACTIVE` seçilirse VIP uyarı verip driver kurmaz (fiziksel olarak
  mümkün değil çünkü UART alıcısı telin üzerinde hiçbir şey sürmez).

Bir gerçek UART linkini test etmek için genelde **iki ayrı `uart_if`**
örneğine ihtiyacın olur: biri DUT'un RX pinine (TX agent sürer), diğeri
DUT'un TX pinine (RX agent dinler).

## Dizin yapısı

```
uart_vip/
├── uart_if.sv                  # Tek seri hat (line) - yön başına bir tane instantiate et
├── uart_vip_pkg.sv             # Tek import noktası
├── uart_transaction.sv         # Sequence item (tek frame: start+data+parity+stop)
├── uart_config.sv              # baud, data bits, parity, stop bits, rol, active/passive
├── uart_callback.sv            # Callback taban sınıfı
├── uart_coverage.sv            # data_bits x parity cross coverage + hata coverage'ı
├── uart_sequencer.sv
├── uart_driver.sv               # Sadece TX rolü için - frame üretir + send_break() task'ı
├── uart_monitor.sv              # Pasif - frame çözer, parity/framing/break tespiti yapar
├── uart_agent.sv                 # Config'e göre TX/RX + active/passive otomatik kurulum
├── seq_lib/
│   └── uart_seq_lib.sv          # Hazır sequence'ler (tekli byte, random stream, string)
└── example/                     # Örnek kullanım (gerçek proje şablonu)
    ├── uart_loopback_checker.sv  # Gönderilen/alınan veriyi karşılaştıran mini scoreboard
    ├── uart_env.sv
    ├── uart_loopback_test.sv
    ├── uart_example_pkg.sv
    └── tb_top.sv
```

> **Gerçek bir RTL DUT'a nasıl bağlanır?** `example_real_dut/` klasörüne
> bak - sentezlenebilir bir UART çekirdeği + onu VIP'e bağlayan tam bir
> testbench + Questa `.do` betiği içeriyor. `example/` sadece VIP-to-VIP
> loopback; gerçek entegrasyonu görmek için `example_real_dut/README.md`'yi
> oku.

## Derleme sırası

```bash
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv \
     uart_vip/uart_if.sv \
     +incdir+uart_vip uart_vip/uart_vip_pkg.sv \
     +incdir+uart_vip/example uart_vip/example/uart_example_pkg.sv \
     uart_vip/example/tb_top.sv

vsim -c tb_top +UVM_TESTNAME=uart_loopback_test -do "run -all"
```

## Kendi projene entegre etmek

1. `uart_vip/` klasörünü (`example/` hariç) projene kopyala.
2. DUT'un RX pinine giden agent:
   ```systemverilog
   uart_config tx_cfg = uart_config::type_id::create("tx_cfg");
   tx_cfg.vif           = <DUT rx pinine bağlı virtual interface>;
   tx_cfg.role          = UART_ROLE_TX;
   tx_cfg.is_active     = UVM_ACTIVE;
   tx_cfg.baud_rate     = 115_200;      // DUT'un beklediği değerle eşleşmeli
   tx_cfg.num_data_bits = 8;
   tx_cfg.parity        = UART_PARITY_EVEN;
   tx_cfg.num_stop_bits = 1.0;
   uvm_config_db#(uart_config)::set(this, "tx_agent*", "cfg", tx_cfg);
   ```
3. DUT'un TX pininden gelen veriyi izlemek için (her zaman passive):
   ```systemverilog
   uart_config rx_cfg = uart_config::type_id::create("rx_cfg");
   rx_cfg.vif       = <DUT tx pinine bağlı virtual interface>;
   rx_cfg.role      = UART_ROLE_RX;
   rx_cfg.is_active = UVM_PASSIVE;
   // ... aynı format alanları (baud/data_bits/parity/stop_bits) TX ile eşleşmeli
   uvm_config_db#(uart_config)::set(this, "rx_agent*", "cfg", rx_cfg);
   ```
4. Veri göndermek için `uart_send_byte_seq`, `uart_random_stream_seq` veya
   `uart_string_seq`'i `tx_agent.sequencer` üzerinde çalıştır.
5. BREAK koşulu üretmek istersen (framed bir transfer olmadığı için
   sequence değil, doğrudan driver task'ı):
   ```systemverilog
   env.tx_agent.driver.send_break();
   ```

## Callback ile genişletme

`example/uart_loopback_checker.sv` bunun canlı bir örneği: `pre_drive`
callback'i gönderilen her byte'ı bir kuyruğa yazıyor, `post_transaction`
callback'i alınan byte'ı bu kuyrukla karşılaştırıp hata/parity/framing
kontrolü yapıyor - VIP kaynağına hiç dokunmadan.

## Notlar / bilinçli tasarım kararları

- Bit sırası UART standardına göre **her zaman LSB-first** sabittir
  (SPI'daki gibi konfigüre edilebilir değil - gerçek UART donanımı hep
  böyle çalışır).
- Format alanları (`num_data_bits`, `parity`, `num_stop_bits`) transfer
  başına değil, agent config'i üzerinden link genelinde ayarlanır - gerçek
  UART hatları da byte başına format değiştirmez.
- Break tespiti bir **heuristic**tir: veri alanı tamamen sıfır VE stop biti
  de düşük geldiyse break olarak işaretlenir. Tam IEEE-doğru break tespiti
  (tam bir frame süresinden uzun düşük seviye) için `uart_monitor.sv`
  içindeki `collect_frame` task'ını genişletebilirsin.
- `UART_MAX_DATA_BITS` (`uart_vip_pkg.sv` içinde, varsayılan 9) VIP'in
  destekleyeceği azami veri genişliğidir.
