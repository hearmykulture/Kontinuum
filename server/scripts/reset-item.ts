import { prisma } from '../src/db/prisma.js';
const itemId = process.env.ITEM_ID || '';
if (!itemId) throw new Error('ITEM_ID is required');
const accts = await prisma.bankAccount.findMany({ where: { itemId }, select: { id: true } });
await prisma.bankTransaction.deleteMany({ where: { accountId: { in: accts.map(a => a.id) } } });
await prisma.bankItem.update({ where: { id: itemId }, data: { cursor: null } });
console.log('Reset complete for', itemId);
await prisma.$disconnect();
