import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String currentPage;
  final Function(String) onPageSelected;

  const AppDrawer({
    super.key,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white70,
                  child: Icon(Icons.person, size: 40, color: Colors.indigo),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome, Admin User',
                  style: TextStyle(
                    color: Colors.white.withValues(),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            title: 'Dashboard',
            isActive: currentPage == 'Dashboard',
            onTap: () {
              onPageSelected('Dashboard');
              Navigator.pop(context);
            },
          ),
          _buildNavItem(
            context,
            icon: Icons.inventory_2,
            title: 'Products',
            isActive: currentPage == 'Products',
            onTap: () {
              onPageSelected('Products');
              Navigator.pop(context);
            },
          ),
          _buildNavItem(
            context,
            icon: Icons.image,
            title: 'Image Upload',
            isActive: currentPage == 'Image Upload',
            onTap: () {
              onPageSelected('Image Upload');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image Upload page coming soon')),
              );
            },
          ),
          _buildNavItem(
            context,
            icon: Icons.shopping_cart,
            title: 'Orders',
            isActive: currentPage == 'Orders',
            onTap: () {
              onPageSelected('Orders');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Orders page coming soon')),
              );
            },
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            isActive: false,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logout functionality coming soon'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper widget to build navigation items
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? Theme.of(context).primaryColor : Colors.grey[700],
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isActive ? Theme.of(context).primaryColor.withValues() : null,
      onTap: onTap,
    );
  }
}
