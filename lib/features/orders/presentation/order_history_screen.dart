import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../common/presentation/widgets/empty_state_widget.dart';
import '../application/orders_notifier.dart';
import 'order_detail_dialog.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(orderHistorySearchQueryProvider));
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final currentLimit = ref.read(orderHistoryLimitProvider);
      ref.read(orderHistoryLimitProvider.notifier).state = currentLimit + 50;
    }
  }

  void _resetLimit() {
    ref.read(orderHistoryLimitProvider.notifier).state = 50;
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _resetLimit();
      ref.read(orderHistorySearchQueryProvider.notifier).state = value;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    _resetLimit();
    ref.read(orderHistorySearchQueryProvider.notifier).state = '';
    ref.read(orderHistoryStatusFilterProvider.notifier).state = null;
    ref.read(orderHistoryDateFilterProvider.notifier).state = null;
    ref.read(orderHistoryDateFromProvider.notifier).state = null;
    ref.read(orderHistoryDateToProvider.notifier).state = null;
  }

  Future<void> _pickCustomDateRange() async {
    final nowLaPaz = TimezoneUtils.getNowLaPaz();
    final currentFrom = ref.read(orderHistoryDateFromProvider);
    final currentTo = ref.read(orderHistoryDateToProvider);

    DateTime initialStartDate = currentFrom != null ? DateTime.parse(currentFrom) : nowLaPaz;
    DateTime initialEndDate = currentTo != null ? DateTime.parse(currentTo) : nowLaPaz;

    if (initialStartDate.isAfter(initialEndDate)) {
      initialStartDate = initialEndDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStartDate, end: initialEndDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECCIONAR RANGO DE FECHAS',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.deepOrange,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final fromStr = DateFormat('yyyy-MM-dd').format(picked.start);
      final toStr = DateFormat('yyyy-MM-dd').format(picked.end);

      _resetLimit();
      ref.read(orderHistoryDateFilterProvider.notifier).state = null;
      ref.read(orderHistoryDateFromProvider.notifier).state = fromStr;
      ref.read(orderHistoryDateToProvider.notifier).state = toStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyOrdersStreamProvider);
    final statusFilter = ref.watch(orderHistoryStatusFilterProvider);
    final searchQuery = ref.watch(orderHistorySearchQueryProvider);
    final exactDate = ref.watch(orderHistoryDateFilterProvider);
    final dateFrom = ref.watch(orderHistoryDateFromProvider);
    final dateTo = ref.watch(orderHistoryDateToProvider);

    final todayStr = TimezoneUtils.getTodayBusinessDate();
    final yesterdayStr = TimezoneUtils.getYesterdayBusinessDate();
    final weekRange = TimezoneUtils.getThisWeekBusinessDateRange();
    final monthRange = TimezoneUtils.getThisMonthBusinessDateRange();

    final isAllDates = exactDate == null && dateFrom == null && dateTo == null;
    final isToday = exactDate == todayStr;
    final isYesterday = exactDate == yesterdayStr;
    final isThisWeek = dateFrom == weekRange.from && dateTo == weekRange.to;
    final isThisMonth = dateFrom == monthRange.from && dateTo == monthRange.to;
    final isCustomRange = dateFrom != null && dateTo != null && !isThisWeek && !isThisMonth;

    final hasActiveFilters = statusFilter != null || searchQuery.isNotEmpty || !isAllDates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpiar Filtros',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // 1. Barra de Búsqueda con Debounce
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, ubicación o # pedido...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _resetLimit();
                          ref.read(orderHistorySearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Filtros de Fecha (Chips rápidos + Personalizado)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: isAllDates,
                    onSelected: (selected) {
                      if (selected) {
                        _resetLimit();
                        ref.read(orderHistoryDateFilterProvider.notifier).state = null;
                        ref.read(orderHistoryDateFromProvider.notifier).state = null;
                        ref.read(orderHistoryDateToProvider.notifier).state = null;
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Hoy'),
                    selected: isToday,
                    onSelected: (selected) {
                      if (selected) {
                        _resetLimit();
                        ref.read(orderHistoryDateFilterProvider.notifier).state = todayStr;
                        ref.read(orderHistoryDateFromProvider.notifier).state = null;
                        ref.read(orderHistoryDateToProvider.notifier).state = null;
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Ayer'),
                    selected: isYesterday,
                    onSelected: (selected) {
                      if (selected) {
                        _resetLimit();
                        ref.read(orderHistoryDateFilterProvider.notifier).state = yesterdayStr;
                        ref.read(orderHistoryDateFromProvider.notifier).state = null;
                        ref.read(orderHistoryDateToProvider.notifier).state = null;
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Esta Semana'),
                    selected: isThisWeek,
                    onSelected: (selected) {
                      if (selected) {
                        _resetLimit();
                        ref.read(orderHistoryDateFilterProvider.notifier).state = null;
                        ref.read(orderHistoryDateFromProvider.notifier).state = weekRange.from;
                        ref.read(orderHistoryDateToProvider.notifier).state = weekRange.to;
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Este Mes'),
                    selected: isThisMonth,
                    onSelected: (selected) {
                      if (selected) {
                        _resetLimit();
                        ref.read(orderHistoryDateFilterProvider.notifier).state = null;
                        ref.read(orderHistoryDateFromProvider.notifier).state = monthRange.from;
                        ref.read(orderHistoryDateToProvider.notifier).state = monthRange.to;
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(isCustomRange ? '${TimezoneUtils.formatDisplayDate(dateFrom)} - ${TimezoneUtils.formatDisplayDate(dateTo)}' : 'Personalizado'),
                    selected: isCustomRange,
                    onSelected: (selected) {
                      _pickCustomDateRange();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Selector de Estado y Botón Limpiar
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        menuMaxHeight: 250,
                        value: statusFilter,
                        hint: const Text('Todos los Estados'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos los Estados', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'PENDING', child: Text('Pendientes', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'DELIVERED', child: Text('Entregados', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'CANCELLED', child: Text('Eliminados / Cancelados', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          _resetLimit();
                          ref.read(orderHistoryStatusFilterProvider.notifier).state = val;
                        },
                      ),
                    ),
                  ),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18, color: Colors.red),
                    label: const Text('Limpiar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // 4. Lista de Resultados con Paginación Infinita
            Expanded(
              child: historyAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (orders) {
                  if (orders.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.search_off,
                        title: 'No encontramos pedidos con estos filtros.',
                        subtitle: 'Prueba cambiando los criterios de fecha, búsqueda o estado.',
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final isCancelled = order.status == 'CANCELLED';

                      final localOrderedAt = order.orderedAt.toUtc().subtract(const Duration(hours: 4));
                      final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(localOrderedAt);

                      return Opacity(
                        opacity: isCancelled ? 0.55 : 1.0,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => OrderDetailDialog(orderId: order.id),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: order.status == 'DELIVERED'
                                  ? Colors.green.shade100
                                  : (isCancelled ? Colors.red.shade100 : Colors.orange.shade100),
                              child: Icon(
                                order.status == 'DELIVERED'
                                    ? Icons.check
                                    : (isCancelled ? Icons.close : Icons.access_time),
                                color: order.status == 'DELIVERED'
                                    ? Colors.green
                                    : (isCancelled ? Colors.red : Colors.orange),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    order.orderNumber != null ? 'Pedido #${order.orderNumber}' : order.customerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCancelled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'CANCELADO',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  'Cliente: ${order.customerName}${order.locationText != null && order.locationText!.isNotEmpty ? " • ${order.locationText}" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$dateFormatted • ${order.paymentMethod}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Text(
                              CurrencyFormatter.formatBOB(order.total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isCancelled ? Colors.grey : Colors.deepOrange,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
