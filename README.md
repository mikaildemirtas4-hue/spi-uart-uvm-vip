# SystemVerilog UVM Verification IP Collection

Yeniden kullanılabilir, gerçek projelerde kullanılmak üzere yazılmış SPI ve UART UVM
Verification IP'leri (UVC). İkisi de master/slave (veya TX/RX) rollerinin ikisini de
destekler, active/passive konfigüre edilebilir, functional coverage ve callback tabanlı
genişletme mekanizması içerir - ve ikisi de **gerçek, sentezlenebilir bir RTL DUT'a
karşı Questa'da uçtan uca doğrulanmıştır.**

| VIP | Ne yapar | Doğrulama |
|---|---|---|
| [`spi_vip/`](./spi_vip) | 4 SPI modu (CPOL/CPHA), master+slave, çoklu CS hattı | Gerçek DUT: **20/20 pass** |
| [`uart_vip/`](./uart_vip) | Konfigüre edilebilir baud/parity/stop-bit, break-condition tespiti | Gerçek DUT: **40/40 pass** |

Her ikisinin de kendi klasöründe detaylı bir `README.md`'si var (mimari, entegrasyon
adımları, sequence kütüphanesi). Bu dosya sadece genel bakış ve hızlı başlangıç için.

## Neden bu repo

Her yeni projede SPI/UART tarafını sıfırdan yazmak yerine, elimin altında hazır,
güvendiğim bir VIP olsun istedim. İkisini de geliştirirken Questa üzerinde adım adım
çalıştırıp gerçek hatalar buldum ve düzelttim - bir SystemVerilog derleyici tuzağı (ref
parametre yön sızıntısı), constraint çakışmaları, ve her iki gerçek RTL DUT'ta da
bulduğum birer zamanlama hatası dahil. Bu VIP'lerin "çalışıyor" demesi, gerçekten
Questa'da uçtan uca koşturulup doğrulandığı anlamına geliyor.

## Hızlı Başlangıç

```bash
git clone <bu-repo>
cd <bu-repo>

# SPI VIP'i kendi projene almak için:
cp -r spi_vip /path/to/your/project/

# UART VIP'i kendi projene almak için:
cp -r uart_vip /path/to/your/project/
```

Derleme sırası ve entegrasyon adımları için her klasördeki `README.md`'ye bak.
İkisinin de içinde ayrıca:
- `example/` — VIP-to-VIP loopback demo + scoreboard (gerçek DUT olmadan hızlı test)
- `example_real_dut/` — sentezlenebilir referans RTL DUT + tam Questa `.do` betiği

## Test Edilen Ortam

- Siemens QuestaSim 2025.2 (UVM-1.2)
- SystemVerilog / IEEE 1800-2012 uyumlu sözdizimi

## Katkı

Bug bulursan veya bir özellik eklemek istersen issue açabilir ya da pull request
gönderebilirsin. VIP'ler aktif olarak kullanılıyor ve bakımı yapılıyor.

## Lisans

Bu proje [Apache License 2.0](./LICENSE) ile lisanslanmıştır - ticari ve kişisel
projelerde özgürce kullanabilir, değiştirebilir ve dağıtabilirsin.

## İletişim

**Mikail Demirtaş** — Digital Design & Verification Engineer
[linkedin.com/in/mikail-demirtaş-44engineer](https://www.linkedin.com/in/mikail-demirta%C5%9F-44engineer/)
