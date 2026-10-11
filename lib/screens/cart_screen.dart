import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/book_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override State<CartScreen> createState() => _CartScreenState();
}
class _CartScreenState extends State<CartScreen> {
  List<Book> books = []; Map<String,int> cart = {}; bool loading = true; bool checkingOut = false;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) setState(() => loading = false); return; }
    try {
      final all = await StoreService.booksOnce();
      final items = await StoreService.getCart(user.uid);
      if (mounted) setState(() { books = all.where((b) => items.containsKey(b.id)).toList(); cart = items; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load cart: $e')));
      }
    }
  }
  double get subtotal => books.fold(0,(s,b)=>s+b.price*(cart[b.id]??0));
  Future<void> _qty(Book b, int qty) async {
    try {
      await StoreService.setCartItem(FirebaseAuth.instance.currentUser!.uid, b.id, qty);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update quantity: $e')));
    }
  }
  Future<void> _checkout() async {
    if (books.isEmpty || checkingOut) return;
    setState(() => checkingOut = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final total = subtotal * 1.08;
      final items = books.map((b) => <String, dynamic>{'bookId': b.id, 'qty': cart[b.id] ?? 1}).toList();
      final id = await StoreService.createOrder(user.uid, items, total);
      await _load();
      if (mounted) await showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text('Order Placed'), content: Text('Order $id placed. View the confirmed total and delivery status in Profile.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    } finally { if (mounted) setState(() => checkingOut = false); }
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(leading:const BackButton(),title:const Text('Shopping Bag'),actions:[TextButton(onPressed:()=>_load(),child:const Text('Refresh'))]),
    body:loading?const Center(child:CircularProgressIndicator()):books.isEmpty?const Center(child:Text('Your shopping bag is empty.')):Column(children:[
      Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[const Icon(Icons.local_shipping_outlined,size:18),const SizedBox(width:8),const Expanded(child:Text('Courier Privilege — complimentary delivery on qualifying orders',style:TextStyle(fontSize:11))),const Text('FREE',style:TextStyle(fontWeight:FontWeight.w700,color:AppTheme.accent))]))),
        const SizedBox(height:8), ...books.map((b)=>Card(child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
          ClipRRect(borderRadius:BorderRadius.circular(5),child:BookImage(source:b.imageUrl,width:55,height:75)),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(b.title,style:Theme.of(context).textTheme.titleMedium),Text(b.author,style:const TextStyle(fontSize:11,color:AppTheme.muted)),const SizedBox(height:7),Text('\$${b.price.toStringAsFixed(2)}') ])),
          Row(children:[IconButton(onPressed:()=>_qty(b,(cart[b.id]??1)-1),icon:const Icon(Icons.remove,size:16)),Text('${cart[b.id]}'),IconButton(onPressed: (cart[b.id]??1) < b.stock ? ()=>_qty(b,(cart[b.id]??1)+1) : null,icon:const Icon(Icons.add,size:16))])
        ])))),
        const SizedBox(height:8), Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[_r('Subtotal',subtotal),_r('Estimated Local Tax',subtotal*.08),_r('Standard Courier',0),const Divider(),_r('Order Total',subtotal*1.08,big:true)]))),
      ])),
      SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(16,6,16,12),child:SizedBox(width:double.infinity,height:48,child:FilledButton(onPressed:checkingOut ? null : _checkout,style:FilledButton.styleFrom(backgroundColor:AppTheme.accent),child:Text('Proceed to Checkout  ·  \$${(subtotal*1.08).toStringAsFixed(2)}'))))),
    ]));
  Widget _r(String a,double b,{bool big=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Text(a,style:TextStyle(fontWeight:big?FontWeight.w700:FontWeight.normal)),const Spacer(),Text('\$${b.toStringAsFixed(2)}',style:TextStyle(fontWeight:big?FontWeight.w800:FontWeight.normal))]));
}
