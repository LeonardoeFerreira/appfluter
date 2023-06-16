import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = openDatabase(
    join(await getDatabasesPath(), 'expenses_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, month TEXT, name TEXT, amount REAL)',
      );
    },
    version: 1,
  );

  runApp(CalendarApp(database));
}

class CalendarApp extends StatelessWidget {
  final Future<Database> database;

  CalendarApp(this.database);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendário Carolseu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CalendarScreen(database),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  final Future<Database> database;

  CalendarScreen(this.database);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late PageController _pageController;
  late DateTime _selectedDate;
  late int _currentPage;
  List<String> _expenses = [];

  //bool _isExpenseAdded = false;


  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentPage = DateTime.now().month - 1;
    _pageController = PageController(initialPage: _currentPage);
    _loadExpenses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _selectedDate = DateTime(DateTime.now().year, index + 1, 1);
      _loadExpenses();
    });
  }

  Future<void> _loadExpenses() async {
    final Database db = await widget.database;
    final String monthKey =
        '${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year.toString()}';
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'month = ?',
      whereArgs: [monthKey],
    );

    setState(() {
      _expenses = List.generate(maps.length, (index) {
        return '${maps[index]['name']} - R\$ ${maps[index]['amount']}';
      });
    });
  }

  Future<void> _addExpense() async {
    String? expenseName;
    double? expenseAmount;

    showDialog(
        context: this.context,
        builder: (BuildContext context) {
      return AlertDialog(
          title: Text('Adicionar Despesa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  expenseName = value;
                },
                decoration: InputDecoration(labelText: 'Despesa'),
              ),
              TextField(
                onChanged: (value) {
                  expenseAmount = double.tryParse(value)!;
                },
                decoration: InputDecoration(labelText: 'Valor'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
          ElevatedButton(
          onPressed: () async {
        final expense = Expense(
          month: '${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year.toString()}',
          name: expenseName!,
          amount: expenseAmount!,
        );
        //await _insertExpense(expense);
        await _insertExpense(expense);
        await _loadExpenses(); // Reload expenses after insertion
        Navigator.of(context).pop();
          },
            child: Text('Adicionar'),
          ),
          ],
      );
        },
    );
  }

  Future<void> _insertExpense(Expense expense) async {
    final Database db = await widget.database;
    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return monthNames[month - 1];
  }

  // Método para remover uma despesa do banco de dados
  Future<void> _removeExpense(int index) async {
    final Database db = await widget.database;
    final String expenseName = _expenses[index].split(' - ')[0];

    await db.delete(
      'expenses',
      where: 'month = ? AND name = ?',
      whereArgs: [
        '${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year.toString()}',
        expenseName,
      ],
    );

    setState(() {
      _expenses.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendário Carolseu'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final month = DateTime(DateTime.now().year, index + 1, 1);
                return Center(
                  child: Text(
                    '${_getMonthName(month.month)} ${month.year}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];

                return Dismissible(
                  key: Key(expense),
                  onDismissed: (direction) {
                    _removeExpense(index); // Remove expense from ListView and database
                  },
                  child: ListTile(
                    title: Text(expense),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Opções'),
                            content: Text('O que você deseja fazer?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  _removeExpense(index); // Remove expense from ListView and database
                                  Navigator.of(context).pop();
                                },
                                child: Text('Remover'),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Implementar a edição da despesa
                                  Navigator.of(context).pop();
                                },
                                child: Text('Editar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: Icon(Icons.add),
      ),
    );
  }
}

class Expense {
  final String month;
  final String name;
  final double amount;

  Expense({required this.month, required this.name, required this.amount});

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'name': name,
      'amount': amount,
    };
  }
}


